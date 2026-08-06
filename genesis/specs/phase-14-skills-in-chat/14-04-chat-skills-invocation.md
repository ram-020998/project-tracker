# Phase 14-04 — Chat skills invocation

> **Status:** ✅ SHIPPED (Phase 14 complete — 14-01..05; see `progress/phase-14-skills-in-chat.md`) · **Repo:** genesis (web) + minor backend · **Depends on:** 14-01 (+ 14-03 for a supply)
> **Goal:** Make skills usable from Chat — the priority-1 experience. Turn the existing `/` composer palette (which
> lists workflows) into a **unified command menu** that also lists installed **skills**; selecting a skill invokes it.
> Auto-activation (by description) also works with no UI. Add a "reload skills" affordance.

---

## 1. Current state (grounded)
- Phase 13-05 gave the Chat `Composer` a **`/` palette** (copilot mode) listing installable **workflows**
  (`useInstalled` + `prereqFor`), arrow/enter/escape nav; selecting one opens the `LaunchDialog` → emits a `start_run`
  intent turn.
- Chat turns are plain ACP `session/prompt` text; the spike proved kiro-cli honors **`/skill-name`** in that text AND
  **auto-activates** a skill when the prompt matches its `description`.
- Skills live in `~/.genesis/.kiro/skills/` (the chat `cwd`), discovered at session start; `GET /api/skills` lists them.

## 2. Design

### 2.1 Unified `/` command menu (resolves the R2 collision)
- Extend the composer palette so typing `/` shows **two sections**: **Workflows** (existing — launchable, prereq-aware)
  and **Skills** (installed skills from `GET /api/skills`, filtered by the text after `/`). Clear section headers +
  distinct icons so the two concepts read as different (per ADR-034).
- Availability by mode: workflows appear in **copilot** mode (they start runs, Phase 13). **Skills appear in both
  read_only and copilot** modes — a skill is just instructions, no mutation, so it's valid for the read-only assistant
  too. (This is a nice win: skills make read-only chat useful for standalone activities without enabling copilot.)
- Selecting a **skill** → send the invocation as the turn:
  - **Primary:** send `/<skill-name> <trailing text>` as the prompt (kiro-cli maps `.kiro/skills` to `/skill` commands;
    trailing text is passed as context). Optionally let the user type context after selecting.
  - This is a normal chat turn — no new backend endpoint needed; the agent applies the skill and replies. The produced
    **document** may be returned inline (Markdown, rendered/copyable) **and/or written to the per-session skill-output
    sandbox** (`~/.genesis/skill-output/<session_id>/`, enabled in 14-05). Surface those outputs in Chat — a small
    "Session outputs" affordance listing `skill-output/<session_id>/` files (preview/download) reusing the **Documents**
    renderers (`DocumentViewer`/`DocumentPreview`). New read endpoints: `GET /api/chat/sessions/{id}/outputs` (+
    `/{name}` content/download), mirroring the run-artifacts endpoints.
- Keep **auto-activation** as the zero-effort path: a user who just describes the task triggers the matching skill by
  `description` with no `/` needed. Document this in the empty-composer hint ("type `/` for workflows & skills, or just
  describe what you need").

### 2.2 Reload affordance
- After install/author/remove (14-01/03), open sessions only see the change on the next client rebuild. Add a small
  **"reload skills"** action (e.g. in the palette footer or a subtle refresh on the Skills section) that calls a
  backend reload (`POST /api/chat/sessions/{id}/reload` or reuse the mode-toggle client-close) so the next turn
  rediscovers. Also invalidate the `GET /api/skills` query on the Skills tab after author/install.

### 2.3 Surfacing an active skill (light)
- Optional: when a skill activates (auto or explicit), render a subtle chip in the transcript ("Skill: gam") if we can
  detect it. Detection over ACP is best-effort (there may be no explicit activation event); if not reliably
  detectable, **skip** for v1 — the reply itself reflects the skill. Do not over-build.

### 2.4 Consistency with 13-05
- Reuse the palette component + keyboard model; add a `kind` to each palette row (`workflow | skill`) and route the
  pick accordingly (workflow → `LaunchDialog`; skill → send `/skill` turn). Keep the read-only placeholder/footer text
  additions.

## 3. Files & tests
- Edit `features/chat/Composer.tsx` (unified palette + sections), `ChatThread.tsx` (skill-pick handler → `send`),
  `features/chat/hooks.ts` (`useInstalledSkills` reuse or a chat-scoped variant), a reload hook. Minor backend: a
  per-session reload endpoint if not reusing mode-toggle.
- Tests (Vitest + MSW, extend `copilot.test.tsx`/`chat.test.tsx`): `/` shows Workflows + Skills sections; filtering;
  selecting a skill sends `/<name>` as the turn text; skills appear in **read_only** mode (workflows do not); reload
  triggers the endpoint; jest-axe. (Auto-activation is a kiro-cli behaviour — covered by the spike, not unit-testable
  headlessly; note the manual check.)

## 4. Acceptance criteria
1. Typing `/` in Chat lists installed **skills** (and workflows) in clearly-separated sections; a skill pick invokes it
   as a chat turn.
2. Skills are available in **both** read-only and copilot chat; workflows remain copilot-only.
3. Newly installed/authored skills become usable in an open session after a reload (affordance provided).
4. Auto-activation works (spike-backed; manual live check recorded); web lint + tsc + tests + jest-axe green;
   `web/static` rebuilt.

## 5. Out of scope
- **Executing** a skill's bundled scripts (14-05 keeps this deferred). *(Writing documents to the per-session
  skill-output sandbox + surfacing them IS in scope — see §2.1 + 14-05.)*
- Node-scoped skills in workflows (later); reliable activation-event detection if the protocol doesn't expose it.
