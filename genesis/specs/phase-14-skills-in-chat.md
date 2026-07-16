# Phase 14 — Skills in Chat (umbrella)

> **Status:** DRAFT (planning only — do NOT implement until approved) · **Author:** Genesis agent · **Date:** 2026-07-16
> **Goal:** Add **Skills** — Kiro's portable, on-demand instruction packages — as a **second first-class capability
> concept** alongside Workflows, and make them **installable, authorable, and invocable from the Chat component**.
> **Priority:** the **Chat** experience is priority 1; workflow-node use of skills is explicitly a later follow-up.
> **Repos:** primarily **genesis** (skills workspace, install/author backend, API, web) + **genesis-workflows** (a
> `skills/` library + registry). **genesis-core** and **kiro-agent-sdk** are expected to need **no change** (skills
> are filesystem-provisioned; the spike proved they work over ACP as-is).
> **Non-negotiable framing:** a **Skill** is a *standalone activity* owned by the Kiro agent (its `SKILL.md`); a
> **Workflow** is a *staged/orchestrated activity* owned by LangGraph (ADR-001). See **ADR-034**.

---

## 0. TL;DR

Today Genesis has one packaged capability: the **workflow** (a LangGraph graph — stages, gates, reliability). Phase
14 adds the **skill**: a portable `SKILL.md` package (+ optional `scripts/`/`references/`/`assets/`) that the Kiro
agent activates on demand to do a **single standalone activity** — draft a document in a house format, build a
checklist, apply a body of knowledge (e.g. a **GAM** skill) — **without any backend orchestration**.

A spike (`spike/2026-07-16-kiro-skills-in-acp-and-chat.md`) proved kiro-cli discovers + activates skills **over ACP**
(the channel Chat uses), via both **auto-activation** (description match) and **explicit `/skill-name`**. Skills are
**filesystem-provisioned** — Genesis writes them into a **managed Kiro workspace at `~/.genesis/.kiro/skills/`**
(which *is* the Chat session's `cwd`), so no SDK/protocol change is needed.

Five pillars:
1. **Foundation + chat discovery** — a managed skills workspace, a skills domain model + local store, and the wiring
   that makes an installed skill usable in a Chat session (14-01).
2. **A skills library** — `genesis-workflows` gains a `skills/` folder + a skills registry; Genesis pulls + installs
   selected skills into the workspace, mirroring the workflow install/lockfile path (14-02).
3. **Catalog Skills tab + in-flight authoring** — the Catalog page splits into **Workflows | Skills** sub-tabs; the
   Skills tab browses/install/remove and offers **"New skill"** (name + description + `SKILL.md` body + scripts/
   references/assets uploads) (14-03).
4. **Chat invocation** — the `/` command palette (today: workflows) becomes a unified menu that also lists installed
   skills; auto-activation also works; a "reload skills" affordance (14-04).
5. **Safety, lifecycle & release** — validation, the script-execution/file-output safety posture, uninstall/update,
   dedup, docs, ADR-034 finalize, release chain (14-05).

---

## 1. Motivation & user story

> *"Workflows are activities that need stages and a backend process — like code review (pull the JIRA ticket → fetch
> the environment data → do the review). But a lot of what I do is a **single standalone activity**: prepare a document
> in the right format, build a checklist, or use a body of domain knowledge like GAM (Government Acquisition
> Management). I don't want a workflow for that. In Kiro we build a **skill** once so we don't repeat the format every
> time, and the agent uses the skill to produce the document. I want that in Chat: type `/`, see the installed skills
> (like I see workflows), pick one, and get the activity done. I want to install skills from our repo, and also create
> a new skill in-flight when the one I need doesn't exist — giving the SKILL.md, any scripts, reference docs, and
> template assets. And I want a **Skills** sub-tab in the Catalog next to Workflows."*

This makes Genesis a **two-concept platform**: **Workflows (orchestrated)** and **Skills (standalone)** — both
browsable in the Catalog and usable from Chat.

---

## 2. Concept boundary — Workflow vs Skill (the crux)

| | **Workflow** | **Skill** |
|---|---|---|
| Nature | staged / orchestrated activity | single standalone activity |
| Owner | **LangGraph** (ADR-001) — durable graph, gates, reliability | **Kiro agent** — driven by `SKILL.md` |
| Runs? | yes — a run, subprocess worker, checkpoints, HITL | **no** — just shapes the agent's turn/output |
| Package | `workflows/<id>/` (graph.py + workflow.yaml + META) | `skills/<id>/` (`SKILL.md` + scripts/references/assets) |
| Lives in | `~/.genesis/library/workflows/` | `~/.genesis/.kiro/skills/` (a Kiro workspace) |
| Invoked | `/` palette → launch dialog → `start_run` (Phase 13) | `/` palette or auto-activation → the agent applies the skill in-turn |
| Example | code-review (JIRA → env → review) | "draft a GAM memo from our template", "build a release checklist" |

**Rule:** if it needs stages/a backend process → **workflow**. If it's a one-shot activity the agent can do in a turn
with the right instructions/templates → **skill**. A skill never starts a run; a workflow never lives in `.kiro/skills/`.

---

## 3. System overview

```
                       ┌───────────────────────── genesis-workflows (library repo) ─────────────────────────┐
                       │  registry.json (workflows[])          skills-registry.json (skills[])               │
                       │  workflows/<id>/**                    skills/<id>/{SKILL.md, scripts/, refs/, assets}│
                       └───────────────┬───────────────────────────────────┬───────────────────────────────┘
                                       │ pull @ref (GitLab client)          │ pull @ref
        ┌──────────────────────────────▼─────────────── genesis app ───────▼──────────────────────────────┐
        │  Installer → ~/.genesis/library/workflows/     SkillInstaller → ~/.genesis/.kiro/skills/<id>/      │
        │  (existing)                                    (14-02) + local author (14-01/03)                   │
        │                                                                                                    │
        │  Catalog API: /catalog, /catalog/available     Skills API: /skills, /skills/available,             │
        │               /library/install|remove                     /skills/install, /skills (create), DELETE│
        └───────────────┬───────────────────────────────────────────────┬────────────────────────────────┘
                        │ GET (Workflows tab)                             │ GET (Skills tab) + author form
        ┌────────────────▼─────────── Catalog page (Workflows | Skills sub-tabs) ──────────────────────────┐
        └───────────────────────────────────────────────────────────────────────────────────────────────┘

  Chat session (ChatManager, in-process kiro-cli, cwd = ~/.genesis):
     kiro-cli auto-discovers ~/.genesis/.kiro/skills/  ── workspace skills ─┐
     + the user's personal ~/.kiro/skills/ (global) ────────────────────────┼──► available in the turn
     `/` palette lists workflows (13-05) + skills (14-04); auto-activation by description
```

Key properties:
- **`~/.genesis/.kiro/skills/` is the single managed skills workspace.** It is the Chat `cwd`, so kiro-cli
  auto-discovers skills there (spike-proven). No `KIRO_HOME` override (keeps the user's `~/.kiro` intact).
- **Skills are files, not wire payloads.** Provisioning = writing the skill folder; discovery is kiro-cli's job.
- **The library path mirrors workflows.** Same GitLab client, same lockfile pattern, a parallel registry — minimal
  new machinery.
- **Chat is the invocation surface.** Auto-activation needs zero UI; the `/` palette makes it explicit + discoverable.

---

## 4. Sub-phases (each has its own detailed spec under `phase-14-skills-in-chat/`)

| Sub-phase | Title | Repos | Outcome |
|---|---|---|---|
| **14-01** | Skills foundation & chat discovery | genesis | Managed skills workspace (`~/.genesis/.kiro/skills/`); `Skill` model + `SKILL.md` parse/validate; `SkillStore`/service (list/get/create/remove local); `/api/skills` (read + local-create + delete); confirm chat discovery + a "reload skills" (rebuild live client). **After this, a skill in the workspace is usable in chat.** |
| **14-02** | Skills library + install-from-repo | genesis-workflows + genesis | `skills/` folder + `skills-registry.json` in the library (+ a CI validation gate); `SkillInstaller`/catalog pulls `skills/<id>/**` at a ref → installs into the workspace; lockfile records installed skills; `/api/skills/available` + `/api/skills/install` + uninstall. |
| **14-03** | Catalog "Skills" tab + in-flight authoring | genesis (web) | Catalog page → **Workflows \| Skills** sub-tabs (standard Tabs). Skills tab: installed + available skill cards, install/remove, and a **"New skill"** author flow (name + description + `SKILL.md` body + `scripts/`/`references/`/`assets/` uploads → create). |
| **14-04** | Chat skills invocation | genesis (web) (+ minor backend) | The `/` composer palette becomes a unified command menu listing **workflows + skills**; picking a skill sends the invocation; auto-activation documented + surfaced; "reload skills" affordance; active-skill affordance. Reconciles the Phase 13-05 workflow palette. |
| **14-05** | Safety, lifecycle & release | genesis (+ genesis-workflows) | `SKILL.md` schema + name/size validation; the script-exec/file-output safety posture (v1 = output-only); uninstall/update; dedup with global `~/.kiro/skills`; audit/telemetry; docs; ADR-034 → Accepted; release chain. |

**Sequencing rationale:** 14-01 is the load-bearing foundation (a workspace skill usable in chat) and de-risked by the
spike; 14-02 gives a supply of skills; 14-03 is the primary authoring/management UX; 14-04 is the chat invocation that
realizes the user story; 14-05 hardens + ships. Each is independently valuable and testable.

---

## 5. Release chain & versioning (ADR-019)

`genesis-workflows` (14-02: `skills/` + skills-registry + CI gate — a library release) and `genesis` (14-01..14-05:
workspace + install/author backend + API + web). **genesis-core and kiro-agent-sdk unchanged** (skills need no engine
or SDK change). Every `web/src` change rebuilds + commits `web/static` (CI stale-bundle guard). Frontend-only genesis
changes still ship a genesis release. Release order: `genesis-workflows` (so a library ref with skills exists) then
`genesis`.

---

## 6. Cross-cutting non-negotiables (carried from the ADRs)

- **ADR-001 preserved** — skills do **not** orchestrate; they shape a single agent turn. LangGraph still owns every
  workflow's control flow. A skill never starts a run.
- **ADR-031 / ADR-033** — Chat/copilot trust + permission model is unchanged. A skill is *instructions*; any tool it
  asks the agent to use is still gated (read tools trusted, mutations confirmed). Skills add no new authority.
- **ADR-026** — local single-user; the managed skills workspace lives under the user's `~/.genesis`.
- **ADR-028** — all new endpoints under `/api`; the web client prepends `/api` centrally.
- **ADR-029/005** — the *library* skills catalog is MR-governed (like the workflow registry); user-authored skills are
  the writable/local tier.
- **ADR-034 (new)** — the Skills concept + boundary (this phase). See the decision log.
- **Standards** — reuse the existing sub-tab (`Tabs`), catalog card, `ResourceManager`/form, and file-preview
  patterns; design tokens not raw colors; jest-axe on new UI; contract fixtures for new API shapes; keep the bible +
  tracker current.

---

## 7. Risks & open questions (resolved per sub-phase)

- **R1 — chat picks up a newly-installed/authored skill only at session start.** kiro-cli discovers skills when the
  ACP session starts; a live chat session won't see a new skill until its client is rebuilt. **Mitigation (14-01/04):**
  a "reload skills" affordance that closes the live client (the mode-toggle path already does this) so the next turn
  rediscovers. De-dup / confirm with a test.
- **R2 — the `/` palette collision.** Phase 13-05's composer intercepts `/` for workflows. **Resolution (14-04):**
  make it a **unified command menu** (Workflows + Skills sections); a skill pick sends `/skill-name` (or an intent).
  Auto-activation remains available with no palette change.
- **R3 — script execution & file output.** Skills may ship `scripts/` and be meant to "produce files". Chat is
  `allow_fs_write=False` and tool-gated. **Resolution (14-05):** v1 skills shape the **chat output** (document-as-reply,
  downloadable via the existing doc viewer); executing bundled scripts / writing files is a **later, explicit**
  fs/tool-policy decision. Authored/imported scripts are treated as untrusted.
- **R4 — where documents a skill "produces" land.** v1: as the assistant's reply content (Markdown/code), which the
  Chat + Documents UI already render/copy/download. Persisting skill outputs as artifacts is a 14-05/later question.
- **R5 — validation & safety of authored/imported skills.** `SKILL.md` frontmatter schema (name matches folder,
  lowercase-hyphen ≤64, description ≤1024), size caps, path-traversal-safe writes, and a clear "imported content is
  untrusted" stance (14-01/05).
- **Q1 — one managed workspace vs per-scope.** Recommend a single `~/.genesis/.kiro/skills/` (workspace scope for
  chat); the user's personal `~/.kiro/skills/` stays active (global), workspace wins on conflict.
- **Q2 — library registry shape.** Extend `registry.json` with a `skills[]` array vs a separate `skills-registry.json`.
  Recommend a **separate `skills-registry.json`** (clean separation, independent validation) — decided in 14-02.

## 8. Out of scope (this phase)
- Skills executing bundled scripts / writing files to disk from Chat (deferred — needs an fs/tool-policy decision).
- Skills inside **workflow nodes** (node-scoped skill injection) — a later follow-up (the mechanism is the same: write
  into the run-workspace `cwd`).
- A marketplace / cross-user sharing beyond the `genesis-workflows` library + local authoring (ADR-026 single-user).
- Editing the *user's personal* `~/.kiro/skills/` (Genesis manages only its own workspace).
