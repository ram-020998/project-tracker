# 10 — Backlog & Future Work

Items captured for later. **Scheduling:** start **after the Developer role vertical slice is
complete** (Phase 2), as part of Phase 4 hardening. Recorded now so they aren't lost.

> **Update 2026-06-26:** BL-1 (environment & secrets registry) and BL-2 (installer app) are now fully
> specified in **doc 13 (design)** and **doc 14 (implementation plan)**, after a working POC of the
> installer extension (`solutions-copilot/installer/`). Treat docs 13/14 as authoritative; the BL-1/BL-2
> notes below are the original seed requirements.

---

## BL-1 — Environment Registry + Secrets Registry

**Goal:** a single, user-maintainable place to manage all target environments and their credentials,
consumed by the sub-agents (atlas-intel, jarvis-intel, data-generator) and role agents.

**Two separated concerns (security):**

| Registry | Committed? | Holds | Format |
|---|---|---|---|
| **Environment registry** | Yes (safe) | Environment names, URLs, web-api endpoints, which products/apps live where, DB type, env type (dev/test/staging/demo) | `environments.json` (repo root) |
| **Secrets registry** | **No** (gitignored / keychain) | API keys, tokens (GITLAB_TOKEN, APPIAN_API_KEY per env), passwords | `.env` (gitignored) and/or OS keychain; `.env.example` shows shape only |

**Requirements:**
- One canonical schema for an environment entry (name, url, apiEndpoint, products[], dbType, type, notes).
- Credentials referenced **by environment name**, never inlined in the registry.
- `setup.sh` reads the environment registry for URLs and the secrets registry for auth, and injects
  them into the generated **`~/.kiro/settings/mcp.json` (or workspace `.kiro/settings/mcp.json`)** —
  MCP servers must be declared there (sub-agents set `includeMcpJson:true`); embedded per-agent
  `mcpServers` don't reach spawned sub-agents (doc 11 §6.5).
- A credential-sync hook (PostToolUse) re-syncs when `.env` changes, so rotations don't require a
  manual re-run.
- Agents resolve an environment by name ("deploy to staging" → look up staging URL + creds).
- Cloud-only usage (atlas-intel) needs just `GITLAB_TOKEN` — most users never configure a live env.
- Must work on **both** Kiro CLI and IDE.

**Open questions:** keychain vs `.env` as the default secret store; per-user vs per-team registry;
how multi-env selection is surfaced to the user.

**Acceptance:** a user can add a new environment + its secret in one documented place, and every
agent/sub-agent can target it by name with no hard-coded URLs or keys.

---

## BL-2 — Installer / Configuration Web App (or HTML page)

**Goal:** a simple UI (web app or single HTML page) that helps a user **install agents** and
**configure the environment registry** without hand-editing JSON — lowering onboarding friction.

**Capabilities (v1):**
- Browse available agents (roles + sub-agents) and skills from `solutions-copilot.manifest.json`;
  select a profile (engineering / product / full) or individual agents.
- Generate/preview the install action (what `setup.sh` will symlink + which MCP images/servers).
- Form-based **environment registry** editor (add/edit/remove environments) that writes
  `environments.json`.
- Secrets entry that writes `.env` **locally only** (never transmitted/committed) — or guidance to
  store in the keychain.
- "Verify" view: show health (creds present, images/servers reachable, symlinks resolved) —
  mirrors `setup.sh --verify`.

**Form factor options (to decide):**
- **Static HTML + JS** that produces files for the user to save / a copy-paste `setup.sh` invocation
  (no backend, safest for secrets — everything stays client-side/local).
- **Local web app** (small server) that can write files directly and run `setup.sh` actions.

**Constraints:**
- Secrets must never leave the user's machine; prefer a fully local/offline page.
- Output must match the manifest + registry schemas exactly (CI-validatable).
- Should support both Kiro CLI and IDE install targets.

**Acceptance:** a new user can, from the page, pick a profile, fill in their environment + token,
and end up with a working install — without manually editing `mcp.json`, `environments.json`, or
agent configs.

---

## Dependencies & sequencing

- Both BL-1 and BL-2 depend on a **stable manifest schema** (`solutions-copilot.manifest.json`) and
  the **agent/skill layout** — which the Developer vertical slice (Phase 2) establishes.
- BL-2 consumes BL-1's `environments.json` schema, so **BL-1 precedes BL-2**.
- Slots into the plan at **Phase 4 (Hardening)** in `07-sequencing-plan.md`.

---

## BL-3 — Workflows / Orchestration (DEFERRED — not required now)

**Goal:** a dashboard-authored, human-gated, multi-step **workflow** an orchestrator runs over the
role agents (e.g. the dev SDLC: design → approve → implement → review → deploy-test → test →
deploy-prod). Explored in full in **doc 19** (idea, 2026 best-practice research, Kiro capability spike,
and native IDE design options C2/C1).

**Status:** 🅿️ **Deferred (2026-06-29).** Sound concept, feasible substrate (native IDE inline approval
gates work; orchestrator delegates to the MCP-owning agents, never nests role agents), **but parked**
behind two prerequisites:
1. The six role agents are **tested, hardened, and verified working** end-to-end (doc 11 §7).
2. **Agent-driven Appian object development is solved** — today implement/deploy is effectively a
   **manual step**; without a reliable agent path to author/deploy Appian objects, the most valuable
   workflow steps can't be automated, so orchestrating them is premature. **This is the real blocker.**

Revisit after those land; doc 19 preserves the design + the two open questions to verify first.
