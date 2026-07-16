# Phase 14-05 — Skills safety, lifecycle & release

> **Status:** DRAFT (planning) · **Repos:** genesis (+ genesis-workflows) · **Depends on:** 14-01..14-04
> **Goal:** Harden skills for real use — validation, a clear script-execution/file-output safety posture,
> update/uninstall/dedup lifecycle, telemetry/audit — then integration + acceptance, ADR-034 finalization, and the
> release chain.

---

## 1. Validation & integrity
- Enforce the `SKILL.md` contract everywhere a skill enters the system (author API, library install, CI): frontmatter
  present; `name` == folder id and `^[a-z0-9-]{1,64}$`; `description` ≤ 1024; total skill size + per-file caps;
  path-traversal-safe extraction (reject `..`, absolute paths, symlinks); allowed file types under `scripts/refs/
  assets`. Malformed skills are skipped in listing (never crash discovery) and rejected on create/install with a clear
  error.
- Consistency: authored + library skills share one validator (`genesis/skills/model.py`); `genesis-workflows`
  `ci/validate_skills.py` uses the same rules so the library can't publish an invalid skill.

## 2. Skill output sandbox & script-execution posture (the key safety decision)
- **Skills MAY produce documents — into a per-session sandbox only.** A skill can write output files, but **only**
  under **`~/.genesis/skill-output/<session_id>/`** (`Settings.skill_output_dir/<session_id>`, defined in 14-01) —
  never the runs/artifacts folder, never arbitrary paths.
- **Mechanism — additive SDK `fs_write_root`.** kiro-agent-sdk's `fs/write_text_file` handler today writes
  `params["path"]` whenever `allow_fs_write` is true (no scoping). Add an option **`fs_write_root: Optional[str]`**:
  when set, the handler **resolves the requested path and rejects any write that escapes the root** (path-traversal-safe:
  `Path(root).resolve()` prefix check; deny symlink escapes). Chat sessions then run with `allow_fs_write=True` **and**
  `fs_write_root = skill_output_dir/<session_id>` — so the agent can save a skill's document, but a write to config,
  secrets, the registry, a workflow file, or anywhere outside the sandbox is refused by the SDK. This is a **bounded
  refinement of ADR-031/033** (chat gains *sandboxed* document output; it gains no other write authority). Applies to
  both read-only and copilot chat (the sandbox is isolated + safe either way).
- **Executing bundled `scripts/` stays deferred.** Skills' `scripts/`/`assets/` are installed and available to the
  model *as reference*, but Genesis never executes them, and chat's tool/permission policy does not auto-run them. A
  "skills may execute scripts" capability is a **separate future ADR + phase**. Imported/authored content is untrusted.
- Document precisely, in the progress doc, what a skill *can* (produce docs into its session sandbox; shape the reply)
  and *cannot* (run scripts; write outside the sandbox) do in chat today.

## 3. Lifecycle
- **Update**: `POST /api/skills/update {id}` reinstalls a library skill at the latest compatible ref (lockfile bump);
  authored skills are edited via re-author (overwrite with confirm).
- **Uninstall**: `DELETE /api/skills/{id}` removes the workspace dir + lockfile entry; never touches the user's
  personal `~/.kiro/skills/`.
- **Dedup / precedence**: document Kiro's rule — a workspace skill (`~/.genesis/.kiro/skills`) shadows a global
  (`~/.kiro/skills`) skill of the same name. Surface in the UI if a managed skill shadows a personal one. Avoid the
  "cwd == home" dedup edge (chat cwd is `~/.genesis`, not home — safe).
- **Reload robustness**: confirm open sessions reliably pick up install/author/remove via the reload path (14-01/04);
  add a regression test.

## 4. Telemetry / audit (light)
- Record skill installs/authors/removes (reuse the existing event/log surface or a small log line) so there's a record
  of what's in the managed workspace and where it came from (library ref vs authored). No new heavy store — the
  `.genesis-source.json` marker + lockfile already capture provenance; expose it read-only in the Skills tab.

## 5. Integration & acceptance
- **E2E (stubbed where possible)**: author a skill via the API → it appears in `GET /api/skills` → a stubbed chat turn
  path confirms the workspace contains it. Install a library skill (LocalSource) → workspace + lockfile updated.
- **Live acceptance (manual, real kiro-cli)**: install/author the **`gam`** skill, then in
  Chat both **auto-activate** it (describe the task) and **explicitly** invoke `/skill-name`, and confirm the reply
  reflects the skill. Record the transcript + skill in `progress/phase-14-skills-in-chat.md`. (The 14-00 spike already
  proved the mechanism; this validates the full Genesis-provisioned path.)
- **Regression**: existing catalog/chat/run suites stay green; the Workflows tab is unchanged.

## 6. Docs & ADR
- Flip **ADR-034** Proposed → Accepted in `reference/decision-log.md`.
- Update `AGENT_ONBOARDING.md` (§0 two-concept framing, §2 state + tags/tests, §4 map — `genesis/skills/` + skills
  workspace + Catalog sub-tabs + chat palette, §5 ADR-034, §7 a skills lesson), `tracker.md` §3/§6, and
  `progress/phase-14-skills-in-chat.md` (as-built + the live-acceptance record).

## 7. Release chain (ADR-019)
`kiro-agent-sdk` (the additive `fs_write_root` option — minor bump) → `genesis-workflows` (14-02 skills library + CI —
a library tag) → `genesis` (14-01..14-05: skills workspace + skill-output sandbox + install/author backend + API + web
+ validation; SDK pin bump). **genesis-core unchanged.** Rebuild + commit `web/static`; verify CI on each repo via
`glab`; frontend-only genesis changes still ship a genesis release.

## 8. Acceptance criteria
1. Every skill (authored + library) passes one shared validator; malformed skills never crash discovery; CI blocks an
   invalid library skill.
2. Skills may write documents **only** under `~/.genesis/skill-output/<session_id>/` (SDK `fs_write_root` sandbox;
   writes outside are rejected — tested); bundled scripts are **not** executed; imported content is untrusted.
3. Update/uninstall/dedup/reload work and never touch the user's personal `~/.kiro`.
4. E2E + a recorded live acceptance (author/install the **GAM** skill, then in Chat auto-activate + `/gam`, and it
   produces a document into the session sandbox); all suites + CI green; ADR-034 Accepted; docs refreshed; release
   shipped.

## 9. Out of scope
- **Executing** skill `scripts/` from chat (separate future ADR + phase). *(Writing documents to the per-session
  sandbox IS in scope.)*
- Node-scoped skills inside workflows (later follow-up; same filesystem mechanism via the run-workspace cwd).
