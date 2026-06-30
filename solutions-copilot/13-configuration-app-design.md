# 13 — Configuration & Onboarding App: Design Spec

**Status:** Proposed (design) · **Supersedes/realizes:** doc 10 BL-1 (Environment & Secrets
Registry) and BL-2 (Installer app) · **Surface:** Kiro IDE extension (CLI parity via shared
artifacts) · **Last updated:** 2026-06-26

> Authoritative design for the Solutions Copilot **configuration & onboarding application** — the
> "unified page" that installs agents/skills, captures the secrets MCP servers need to run, and
> maintains a **labeled environment registry the agents read at runtime**. Companion build plan:
> **doc 14**.

---

## 0. Two decoupled concerns (read this first)

A clarification (2026-06-26) reshaped the design. There are **two separate things**, and they must
not be conflated:

| | **A. MCP secrets / connection config** | **B. Environment registry** |
|---|---|---|
| What | The env vars an MCP **server needs to function** (e.g. Jarvis must connect to a working Appian environment: `APPIAN_BASE_URL` + `APPIAN_API_KEY`; Atlas needs `GITLAB_TOKEN`). | A set of **reference data the agent reads at runtime**, keyed by label: `url`, `api_endpoint`, `products`, `type`, `notes`. |
| Secret? | Yes (API keys). | **No** — pure connection metadata. |
| Who consumes it | The MCP **server process**, via its launch env. | The **agent's reasoning** (and its `read` tool), by label, per request. |
| When | At MCP launch. | Whenever the user references an environment ("pull this from gam-dev2"). |
| This release | **Plaintext** store, substituted into a generated **`.kiro/settings/mcp.json`** (keychain on the roadmap). | Managed data file + steering pointer; agent looks it up. |

Example registry entry (exactly the shape we support):
```jsonc
"gam-dev2": {
  "url": "https://eng-test-fed-aq-dev2.appianpreview.com",
  "api_endpoint": "https://eng-test-fed-aq-dev2.appianpreview.com/suite/webapi/",
  "products": ["source-selection", "vendor-management", "contract-writing"],
  "type": "development",
  "notes": "Primary GAM development environment"
}
```

The rest of this doc designs both, kept separate.

---

## 1. Purpose & scope

Turn the validated POC installer into a **standard, modern configuration application** (private Kiro
IDE extension, CLI parity via shared artifacts) that lets a user:

1. Install/update **role agents + skills** from the private GitLab repo (runtime fetch) — guided.
2. Capture the **secrets/connection config each MCP server needs to run** — once, never hand-edited.
3. Maintain a **labeled environment registry** the agents read by label at runtime.
4. **Verify** the setup (token valid, Docker reachable, MCP launches, files present).

**Out of scope (this doc):** building the remaining role agents (doc 09/12), the orchestrator, and
the Atlas/Jarvis merge.

---

## 2. POC learnings (carry forward / fix)

| # | Learning | Consequence |
|---|---|---|
| L1 | **Engine version blocks activation** (`^1.85` → silent no-load; `^1.74` fixed it). | Conservative engine floor + compatibility self-check. |
| L2 | **Discovery matters** — activity-bar view + welcome button made it usable. | Activity-bar container is the app home. |
| L3 | **Install-target control was confusing, not broken** ("Global" pre-checked → no visible change; "Workspace" disabled with no folder). | Replace with explicit **selectable cards** + resolved paths + "Open a folder." |
| L4 | **Flat single page doesn't scale.** | **Guided stepper** + dedicated management views. |
| L5 | **`.env` bridge wasn't automatic.** | App **substitutes secrets into generated MCP configs** (§7). |
| L6 | **Zero-dep, runtime-fetch, themed-webview** worked well. | Keep as principles. |

---

## 3. Goals, non-goals, principles

### 3.1 Goals
- **G1** — onboarding under 5 minutes from "installed" to "developer agent answering."
- **G2** — **no manual file editing, ever** (MCP configs, registry, steering are generated/managed).
- **G3** — secrets captured once; this release stores them in a single `0600` gitignored file and
  substitutes them into generated MCP configs. **Keychain is a roadmap upgrade behind a stable seam.**
- **G4** — a **labeled environment registry** the agents read by label, supporting per-request lookup
  (the agent can reference different environments in the same session).
- **G5** — push updates easily (runtime fetch + ref pinning + update detection); updates preserve
  secrets + registry.
- **G6** — **dual-surface** (CLI `.json` + IDE v3 frontmatter) generated from one source, in sync.
- **G7** — private end-to-end (GitLab only).

### 3.2 Non-goals (v1)
- Editing/authoring skills from the UI (install/update only).
- Team-shared central registry server (local registry first; team sync is future).
- A launch-time secret resolver / keychain (roadmap — see §7.4).

### 3.3 Principles
- **Standard over bespoke** — activity-bar container, themed webview, settings, status bar.
- **Declarative source of truth** — manifest + registry + secrets store + lockfile fully describe a
  deployment; agent configs/steering are generated.
- **Idempotent & reversible** — install/update/regenerate are idempotent; uninstall cleans up.
- **Swappable secret backend** — all secret access goes through a `SecretProvider` interface so the
  plaintext→keychain change is one line, not a rewrite.
- **Progressive disclosure**, **accessible by default** (§13).

---

## 4. Personas & primary journeys
**Personas:** *Solutions Engineer* (primary), *Tech Lead* (manages registry + rotates keys),
*New Joiner* (zero-config onboarding).

- **J1 First-run:** install → open → connect → pick profile → choose location → enter MCP secrets →
  (optional) add registry environments → install → verify → use the agent.
- **J2 Add a registry environment:** Environments view → Add → fill label/url/api_endpoint/products/
  type/notes → save → written to the registry + steering refreshed.
- **J3 Rotate an MCP secret:** Secrets view → update `jarvis / APPIAN_API_KEY` → save → MCP configs
  regenerate → next launch uses it. No reinstall.
- **J4 Reference an env at runtime:** user tells the agent "use gam-dev2" → agent reads the registry
  by label → uses that url/api_endpoint. (No switching UI needed.)
- **J5 Update agents/skills:** "update available (tag vX)" → review → update → content re-fetched;
  secrets + registry untouched.
- **J6 Verify/troubleshoot:** Status view → green/red checks for token, Docker, MCP launch, files,
  secrets present.

---

## 5. Information architecture & UX

### 5.1 App shell
Activity-bar container "Solutions Copilot" hosting a launcher; rich screens render in a **full-tab
webview app** with left nav:
- **Home / Setup** — first-run wizard (re-runnable).
- **Agents & Skills** — installable/installed; update status.
- **MCP Connections** — per-MCP-server connection/secret config (the secrets layer).
- **Environments** — the labeled reference registry (CRUD).
- **Status** — verification & diagnostics.

Status bar carries lightweight affordances (update-available badge). Rationale for full-tab: registry
and secret tables are too wide for the sidebar.

### 5.2 First-run wizard (stepper)
```
[1 Connect] → [2 Choose] → [3 Location] → [4 MCP secrets] → [5 Environments] → [6 Review] → [7 Verify]
```
- **1 Connect** — GitLab host/project/ref (prefilled) + token; "Test connection" → manifest version +
  latest tag; specific 401/403/404 remediation.
- **2 Choose** — profile chips (`engineering`, `full`, custom) + role list with descriptions and skill
  expanders; **auto-included dependencies shown explicitly** (sub-agents + shared skills); `planned`
  roles disabled ("coming soon").
- **3 Location** — two **selectable cards** (fixes L3): *Global* (`~/.kiro`, default) and *This
  workspace* (`<folder>/.kiro`, with an **"Open a folder"** action when none is open). Each shows the
  resolved path + "installed here (vX)" badge.
- **4 MCP secrets** — for the MCP servers the selected agents use, show the env vars each needs
  (from the manifest), masked inputs, "stored ✓ / not set", optional **Test** (validate token, ping
  URL). Jarvis's working connection (`APPIAN_BASE_URL` + `APPIAN_API_KEY`) is just one of these. Atlas
  needs only `GITLAB_TOKEN` (reuses Step 1). Saved to the secrets store.
- **5 Environments** (optional/skippable) — manage the labeled reference registry (table + add/edit
  form, schema §6.3). Explains: "this is reference data your agents read by label; it is **not**
  credentials and does **not** connect any tool."
- **6 Review** — summary + **exactly what will be written/generated** (file list, which MCP configs
  get values substituted, registry + steering files). Nothing written before confirm.
- **7 Verify** — health checks (§11) live, with "Open the developer agent."

### 5.3 Ongoing management views
- **Agents & Skills** — installed set + versions; update with changelog/diff; add/remove roles.
- **MCP Connections** — per-server connection/secret editing; rotate; regenerates configs on save.
- **Environments** — full CRUD over the reference registry; edits refresh the data file + steering.
- **Status** — verification dashboard + "Repair" (regenerate all configs).

### 5.4 Interaction & visual standards
Theme via VS Code CSS vars (light/dark/high-contrast); explicit pending/success/error states;
confirmation + blast-radius on destructive actions; inline validation; keyboard-navigable.

---

## 6. Domain model & schemas

### 6.1 Manifest (extended)
`solutions-copilot.manifest.json` stays the install contract; add display metadata + each MCP's
`envKeys` (the vars the secrets layer must fill):
```jsonc
{
  "version": "0.3.0",
  "agents": {
    "roles": [{ "name": "developer", "title": "Developer", "summary": "…", "skills": ["…"], "subAgents": ["atlas-intel","jarvis-intel","integrations"] }],
    "intelligence": [{ "name": "atlas-intel", "summary": "…", "mcp": "appian-atlas" }],
    "integrations": [{ "name": "integrations", "summary": "…", "mcp": ["jira","google-workspace","playwright"] }]
  },
  "skills": { "shared": [{ "name": "sail-reference", "summary": "…" }], "developer": [{ "name": "code-review", "summary": "…" }] },
  "mcp": {
    "appian-atlas": { "owner": "atlas-intel",  "image": "…", "envKeys": ["GITLAB_TOKEN","ATLAS_KB_PROJECT_ID","ATLAS_DATA_PREFIX"], "mode": "read-only" },
    "jarvis":       { "owner": "jarvis-intel", "image": "…", "envKeys": ["APPIAN_BASE_URL","APPIAN_API_KEY","JARVIS_SITES_CONFIG"], "mode": "read-write-deploy" }
  },
  "profiles": { "engineering": ["developer"], "full": "*" },
  "planned": { "roles": ["tester","ux-designer","product-owner","devops","documentation"], "intelligence": ["data-generator"] }
}
```
Note: `envKeys` are **not** classified by environment any more — they are simply the variables a given
MCP server needs to run. Some are secret (`APPIAN_API_KEY`), some not (`APPIAN_BASE_URL`,
`ATLAS_DATA_PREFIX`); all are entered/managed in the MCP-secrets layer and substituted into configs.

### 6.2 MCP secrets store — `~/.kiro/.solutions-copilot/secrets.json` (generated, `0600`, gitignored)
The canonical source for values substituted into MCP configs. Flat map keyed by MCP server + var:
```jsonc
{
  "version": 1,
  "values": {
    "global/GITLAB_TOKEN": "glpat-…",
    "jarvis/APPIAN_BASE_URL": "https://…",
    "jarvis/APPIAN_API_KEY": "…",
    "jarvis/JARVIS_SITES_CONFIG": "…"
  }
}
```
`global/*` values are shared across servers (e.g. the GitLab token used by Atlas). All access goes
through the **`SecretProvider`** interface (§7.3) so the file backend can be swapped for the keychain.
**Never displayed back in the UI** (write-only; presence shown as a badge).

### 6.3 Environment registry — `environments.json` (managed; reference data only, **committable**)
Matches the user's real shape; **no secrets**:
```jsonc
{
  "version": 1,
  "environments": {
    "gam-dev2": {
      "url": "https://eng-test-fed-aq-dev2.appianpreview.com",
      "api_endpoint": "https://eng-test-fed-aq-dev2.appianpreview.com/suite/webapi/",
      "products": ["source-selection","vendor-management","contract-writing"],
      "type": "development",
      "notes": "Primary GAM development environment"
    }
  }
}
```
Rules: label (the key) is unique. `type` is free-ish (development/test/staging/production/demo).
Because it carries no secrets, it can be committed/shared. The agent reads it **by label** at runtime
(§8).

### 6.4 Install lockfile — `~/.kiro/.solutions-copilot/installed.lock.json` (generated)
Records ref, target, roles/sub-agents, file hashes, and the list of generated files — for update
detection, repair, and clean uninstall.

---

## 7. MCP secrets → server (how values reach the MCP)

### 7.1 Mechanism: substitution at generation time (no launcher in v1)

> **⚠️ Correction (2026-06-30) — verified in the Kiro IDE.** Secrets are substituted into a generated
> **`.kiro/settings/mcp.json`** (built from a committed `mcp.json.template`), **not** into each
> (sub-)agent's embedded `mcpServers` block. Reason: **MCP servers embedded in an agent config do NOT
> start when that agent is spawned as a *sub-agent*** — only servers declared in `mcp.json` reach
> spawned sub-agents (workspace-scoped confirmed working). So the MCP-owning sub-agents now set
> **`includeMcpJson: true`** with `tools` scoped to their server, and the installer writes the resolved
> `mcp.json` (mode 0600, filtered to the installed servers). The substitution concept below is
> unchanged — only the *target file* moved from agent blocks to `mcp.json`. See doc 11 §6.5.
Kiro launches each MCP from the `mcpServers.<name>.env` block. Source configs in GitLab keep
`${VAR}` placeholders (no secrets in the repo). At **install/update and on any secret change**, the
app **fetches the (sub-)agent configs, substitutes `${VAR}` → the stored value, and writes the
resolved config** to the target:
```jsonc
// generated ~/.kiro/agents/jarvis-intel.json (and the -prompt.md v3 frontmatter)
"jarvis": {
  "command": "docker",
  "args": ["run","--rm","-i","--env","APPIAN_BASE_URL","--env","APPIAN_API_KEY","…jarvis-image"],
  "env": { "APPIAN_BASE_URL": "https://…", "APPIAN_API_KEY": "AQAB-real-key…" }
}
```
Kiro sets these as env vars on the MCP process; `docker run --env NAME` forwards them into the
container; the server reads them as usual. **No launcher, no manual editing.**

### 7.2 Flow
1. User enters MCP secrets → app writes `secrets.json` (`0600`, gitignored).
2. App fetches sub-agent configs (placeholders) → **substitutes** via `SecretProvider` → writes
   resolved `.json` + `-prompt.md` frontmatter to the target (dual-surface, in sync).
3. Kiro launches MCP with literal env → docker forwards → MCP works.
4. Rotate: edit value in app → `secrets.json` updates → **regenerate** configs. User edits nothing.

### 7.3 The `SecretProvider` seam (enables the keychain roadmap)
```ts
interface SecretProvider {
  get(key: string): Promise<string | undefined>;   // e.g. "jarvis/APPIAN_API_KEY"
  set(key: string, value: string): Promise<void>;
  delete(key: string): Promise<void>;
  has(key: string): Promise<boolean>;
}
```
- **v1: `PlaintextProvider`** — reads/writes `secrets.json`. The generator substitutes values into
  configs (secrets live in `secrets.json` + the generated configs, both `0600`/gitignored).
- **Roadmap: `KeychainProvider`** — values live in the macOS keychain; configs then reference a tiny
  `sc-mcp` launcher (`command: sc-mcp launch jarvis`) that resolves secrets at spawn, so **no
  plaintext touches disk**. Swapping providers + flipping the generator from "substitute literals" to
  "emit launcher reference" is the entire change.

### 7.4 Security posture (v1 vs roadmap)
- **v1 (accepted):** secrets in `secrets.json` and in generated configs — both `0600` and gitignored;
  local-user-only. Documented clearly.
- **Roadmap:** keychain + `sc-mcp` launcher removes on-disk plaintext (see §10).

---

## 8. Environment registry at runtime (read by label)

The registry is **reference data the agent reads**; nothing connects through it. Delivery so the
agent can use it with **no MCP changes**:
1. The app writes `environments.json` to a known location the agent can `read` (the install target,
   e.g. `~/.kiro/environments.json` or the workspace `.kiro/environments.json`).
2. The app generates/updates a **steering file** (`steering/environments.md`) that: enumerates the
   available labels + their `type`/`products`, states where the full data lives, and instructs the
   agent — "when the user references an environment by label, read this file/entry and use its
   `url`/`api_endpoint`." This puts the label vocabulary in the agent's always-on context cheaply,
   while the full details load on demand via `read`.
3. Per-request, multi-environment is natural: the agent resolves whatever label(s) the user mentions
   from the registry within a single session — no "active environment," no switching UI.

> Distinction: an MCP **server's own working connection** (e.g. Jarvis must be connected to one Appian
> environment to operate) is configured in the **secrets layer** (§7), independently of this registry.
> They may point at the same physical environment but are configured separately.

---

## 9. Update & versioning
- Runtime fetch at the configured `ref`; pin a tag for stable installs.
- App compares lockfile `ref` to latest tag → "update available" + a file-hash diff summary.
- Updates re-fetch **content only**; `secrets.json` and `environments.json` are preserved; configs
  are **regenerated** (re-substituting current secrets). Schema-version fields enable migrations.

---

## 10. Security model
- **v1 plaintext, scoped:** `secrets.json` and generated configs are `0600` + gitignored, local-user
  only. The reported posture and its roadmap are documented in-app.
- **Least privilege:** minimal GitLab scopes (`read_api`/`read_repository`); prefer per-tool/per-env
  API keys so a dev key can't touch prod.
- **No secrets in the repo or the registry:** GitLab configs keep `${VAR}`; `environments.json` is
  secret-free (hence committable).
- **Destructive actions** confirm + state blast radius; uninstall removes generated files (and offers
  to wipe `secrets.json`).
- **Supply chain:** pin MCP image tags/digests in the lockfile; verify fetched manifest/files against
  schemas before use.
- **Roadmap:** keychain + `sc-mcp` removes on-disk plaintext entirely (§7.3).

---

## 11. Health & verification (Status view)
Each check: pass/warn/fail + remediation.
1. **Engine/compatibility** — Kiro API ≥ floor; extension active.
2. **GitLab** — token valid; project+ref reachable; manifest parses.
3. **Docker** — daemon reachable; required images present/pullable.
4. **MCP secrets complete** — every `envKey` for each installed MCP has a value.
5. **Configs resolved** — generated agent configs contain no leftover `${VAR}` placeholders.
6. **Per-MCP launch** — dry-run launch/handshake of each MCP.
7. **Files** — installed files present + hash-match the lockfile (drift detection).
8. **Registry** — `environments.json` valid; steering pointer present.
"Repair" regenerates configs/steering and re-verifies.

---

## 12. Diagnostics & telemetry
Local rotating log under `~/.kiro/.solutions-copilot/logs/`. No remote telemetry by default; any
future telemetry is opt-in, no secrets/PII.

---

## 13. Accessibility & i18n
Full keyboard operability; visible focus; ARIA on stepper/tables/dialogs; high-contrast support;
labels on icon-only buttons; centralized strings for later localization.

---

## 14. Decisions (status)
- **D1 — Keychain mechanism:** N/A for v1 (plaintext). When the keychain roadmap lands, use the
  macOS `security` CLI (audience is mac-only) behind `KeychainProvider`. **Settled.**
- **D2 — Webview UI stack:** **Preact + esbuild.** **Settled (2026-06-26).**
- **D3 — Companion launcher distribution:** **Deferred** — no launcher in v1 (substitution model).
  When keychain lands, ship `sc-mcp` as a bundled Node script run via Kiro's Node. **Settled for v1.**
- **D4 — Per-request multi-env:** **Resolved** — naturally supported; the agent reads the registry by
  label per request. No active-env/per-label-instance machinery needed.
- **D5 — Registry scope:** **Local-only v1** (committable file); team-shared source is future.
  **Settled.**
- **D6 — URL as secret vs registry field:** **Resolved** — `url`/`api_endpoint` are non-secret
  reference fields in `environments.json`; only API keys are secrets (in the MCP-secrets layer).
- **D7 — Secret storage backend:** **v1 plaintext `secrets.json`** (substituted into configs);
  **keychain on the roadmap** behind `SecretProvider`. **Settled (2026-06-26).**

---

## 15. Relationship to existing docs
Realizes doc 10 BL-1/BL-2. Consumes doc 04 (repo), doc 02 §2.1 (dual-surface), doc 09 (manifest/
agents). Implementation: doc 14. Updates doc 07 Phase 4 to point here.
