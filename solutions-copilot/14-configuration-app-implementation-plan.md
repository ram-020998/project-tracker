# 14 — Configuration & Onboarding App: Implementation Plan

**Status:** Proposed · **Design:** doc 13 · **Working repo:** `solutions-copilot/installer/`
**Last updated:** 2026-06-26

> Executable plan to evolve the POC installer (`installer/`, v0.1.2) into the full app in doc 13.
> Incremental — the POC keeps working at every step. Reflects the two-concern split: **(A) MCP
> secrets** (plaintext now, keychain on the roadmap) and **(B) environment registry** (agent-read
> reference data).

---

## 1. Approach
- **Incremental, vertical-slice-first.** Each phase ends with a usable, packaged `.vsix`, a passing
  headless test suite, and a manual Kiro checklist. No big-rewrite branch.
- **Generated, declarative.** Manifest + `secrets.json` + `environments.json` + lockfile are the
  sources of truth; agent configs, MCP env blocks, and steering are generated.
- **Decouple logic from VS Code.** All pure logic (resolution, schema validation, config generation
  via substitution, env-key math) lives in vscode-free modules, unit-tested with `node` (as the POC
  smoke test proves). Only `app/*`, `infra/*` touch `vscode`.
- **Swappable secrets** via a `SecretProvider` interface (plaintext now → keychain later).

---

## 2. Tech stack decisions

| Concern | Decision | Rationale |
|---|---|---|
| Webview UI (D2) | **Preact + esbuild** | Tiny, componentized, fast builds, single bundle for a tight CSP. |
| Build | **esbuild** for host (`out/`) + webview (`media/dist/`) | One fast bundler. |
| Secrets backend (D7) | **`PlaintextProvider`** over `~/.kiro/.solutions-copilot/secrets.json` (`0600`, gitignored), behind a `SecretProvider` interface | Lightest path now; **`KeychainProvider` (macOS `security` CLI) is the one-line roadmap swap** (D1). |
| Secret delivery | **Substitution at generation time** — the installer substitutes `${VAR}` with stored values into a generated **`.kiro/settings/mcp.json`** (from `mcp.json.template`); sub-agents set `includeMcpJson:true` | **Corrected 2026-06-30:** embedded per-agent `mcpServers` don't reach spawned sub-agents in the IDE; only `mcp.json` servers do. See doc 11 §6.5. |
| Launcher (D3) | **None in v1.** `sc-mcp` (bundled Node script) arrives only with the keychain roadmap. | Substitution removes the need. |
| State (webview) | Typed store + `postMessage` bus | Explicit protocol (§5). |
| Validation | **JSON Schema (ajv)** for manifest, registry, secrets, lockfile | Validate inputs; power form validation. |

Runtime deps stay minimal and bundled; the `.vsix` remains small and offline-installable.

---

## 3. Target repo layout (`installer/`)
```
installer/
├── package.json                 # contributes: activitybar container, views, commands, settings
├── esbuild.mjs                  # builds host + webview bundles
├── tsconfig.json
├── schemas/                     # manifest / environments / secrets / lockfile JSON Schemas
├── src/
│   ├── extension.ts             # activate: register views, commands, providers
│   ├── app/
│   │   ├── panel.ts             # full-tab webview app host + message bus
│   │   └── launcherView.ts      # activity-bar webview view (home/launcher)
│   ├── core/                    # vscode-FREE (unit-testable)
│   │   ├── manifest.ts          # parse/validate; catalog; dependency resolution
│   │   ├── envkeys.ts           # (exists) env-key math
│   │   ├── registry.ts          # environments.json read/write/validate (reference data)
│   │   ├── secretsStore.ts      # PlaintextProvider (SecretProvider impl) over secrets.json
│   │   ├── secretProvider.ts    # SecretProvider interface (+ future KeychainProvider)
│   │   ├── lockfile.ts          # installed.lock.json read/write/diff
│   │   ├── planner.ts           # selection → file plan (extends POC installer.ts)
│   │   ├── generator.ts         # substituteVars(${VAR}->value) for agent files
│   │   ├── mcpConfig.ts         # build .kiro/settings/mcp.json from mcp.json.template (secrets + filter)
│   │   ├── steering.ts          # generate steering/environments.md (label vocabulary + pointer)
│   │   └── gitlab.ts            # (exists) GitLab client
│   ├── infra/                   # vscode/OS-touching
│   │   ├── writer.ts            # filesystem writes into target .kiro (extends POC); 0600 + .gitignore
│   │   ├── docker.ts            # docker availability/image checks
│   │   └── health.ts            # verification checks (doc 13 §11)
│   └── messages.ts              # shared host ⇆ webview protocol types
├── webview/                     # Preact app (built to media/dist/)
│   ├── main.tsx                 # app shell + left nav + router-lite
│   ├── store.ts                 # typed state + dispatch
│   ├── steps/                   # Connect, Choose, Location, McpSecrets, Environments, Review, Verify
│   ├── views/                   # AgentsSkills, McpConnections, Environments, Status
│   └── components/              # Stepper, Card, Table, SecretInput, HealthBadge, …
└── test/
    ├── smoke.js                 # (exists) extend
    └── *.test.js                # planner / generator(substitution) / registry / secretsStore / lockfile
```
Note: **no `companion/` dir in v1** — the launcher returns only with the keychain roadmap.

---

## 4. Data contracts (JSON Schemas in `schemas/`)
- **manifest.schema.json** — doc 13 §6.1 (agent/skill metadata + per-MCP `envKeys`).
- **secrets.schema.json** — doc 13 §6.2 (`values` map; key grammar `global/<KEY>` | `<server>/<KEY>`).
- **environments.schema.json** — doc 13 §6.3 (label → `url`,`api_endpoint`,`products`,`type`,`notes`;
  **no secret fields permitted**).
- **lockfile.schema.json** — doc 13 §6.4.
All validated with ajv at read time; UI reuses them for form validation. A schema test asserts the
environments schema **rejects** any secret-looking field.

---

## 5. Message protocol (host ⇆ webview) — `src/messages.ts`
Webview→host: `ready`, `testConnection`, `loadCatalog`, `saveSelection`, `getMcpSecrets`,
`setMcpSecret`, `deleteMcpSecret`, `testSecret`, `listEnvironments`, `upsertEnvironment`,
`deleteEnvironment`, `install`, `update`, `verify`, `repair`, `pickFolder`, `uninstall`.
Host→webview: `init`, `catalog`, `connectionResult`, `mcpSecretsState`, `environments`, `plan`,
`progress`, `installed`, `verifyResult`, `updateAvailable`, `error`. Correlation id per request;
terminal `…Result`/`error` per handler.

---

## 6. Phased plan

### Phase A — Foundation & app shell (closes L2/L3/L4)
- esbuild for host+webview; Preact shell with left nav + the management views + stepper frame.
- Convert launcher to open the full-tab app.
- **Fix install-target (L3):** selectable cards + resolved paths + "Open a folder" + "installed here."
- Port POC connect+select+install into the shell (parity); `messages.ts` + typed store.
**Exit:** app opens/navigates; installs developer role as the POC did; smoke tests green; `.vsix`
packaged; manual checklist passes.

### Phase B — Wizard UX (Steps 1–3)
- Connect (specific 401/403/404), Choose (catalog metadata, expanders, dependency disclosure, planned
  disabled), Location (cards + folder picker).
- `core/manifest.ts` catalog + dependency resolution (role → sub-agents/shared skills) + tests.
**Exit:** steps 1–3 clear/validated; unit tests for catalog/dependency resolution.

### Phase C — Environment registry (reference data)
- `core/registry.ts` (+schema): CRUD over `environments.json` (label→reference data); validation;
  reject secret fields.
- `core/steering.ts`: generate `steering/environments.md` (labels, types, products, "read this by
  label" instruction + data location).
- Step 5 + **Environments** view: table + add/edit form (url/api_endpoint/products/type/notes).
- `infra/writer.ts`: write `environments.json` to the target where the agent can `read` it.
**Exit:** user defines labeled environments; persisted + validated; steering pointer generated;
agent can resolve a label by reading the file. Unit tests for registry + steering generation.

### Phase D — MCP secrets + substitution generator (the core)

> **⚠️ Corrected 2026-06-30 (implemented):** the generator writes a **`.kiro/settings/mcp.json`** (from
> `mcp.json.template`, secrets substituted, filtered to the installed servers) — **not** per-agent
> `mcpServers` blocks. MCP-owning sub-agents set `includeMcpJson:true` + scoped `tools`; role agents
> stay `includeMcpJson:false`. Implemented in `core/mcpConfig.ts` (`buildMcpJson`/`serversForAgents`)
> + `InstallService`. Reason + evidence: doc 11 §6.5.
- `core/secretProvider.ts` interface + `core/secretsStore.ts` (`PlaintextProvider` over
  `secrets.json`, `0600`).
- `core/generator.ts`: fetch sub-agent configs (placeholders) → **substitute `${VAR}` → value** via
  the provider → emit resolved `.json` + v3 `-prompt.md` frontmatter (dual-surface, in sync).
- Step 4 + **MCP Connections** view: per-server env-var inputs (masked), presence badges, Test.
- Wire install: write content (planner/writer) → generate resolved configs → write `secrets.json` →
  write lockfile. Ensure target `.gitignore` covers `secrets.json` + generated agent configs.
**Exit (critical):** on a real Mac, install developer + enter Jarvis `APPIAN_BASE_URL`/`APPIAN_API_KEY`
once → launch the agent → the Jarvis MCP connects, **with no manual file edits**. Generator unit tests
assert resolved configs contain the values and **no leftover `${VAR}`**; rotation regenerates.

### Phase E — Verify, update, polish
- `infra/health.ts` + **Status** view: all doc 13 §11 checks (incl. "no leftover `${VAR}`" and "MCP
  secrets complete"), with Repair.
- Update detection (lockfile vs latest tag) + diff + content-only update preserving secrets/registry.
- Accessibility pass; error/empty/loading states.
**Exit:** Status green on a healthy setup; update preserves secrets + registry; a11y checklist passes.

### Phase F — Packaging & private distribution
- `.gitlab-ci.yml`: build, headless tests, `vsce package`, **publish `.vsix` to a GitLab Release** on
  tag (+ Generic Package Registry). **Full pipeline design + ready-to-use YAML: doc 15.**
- One-line **bootstrap script** to fetch the latest `.vsix` via the Releases API using the user token.
- Conservative `engines.vscode` floor + compatibility self-check (L1). Installer README + in-app Help.
**Exit:** `git tag vX` → CI publishes a privately installable `.vsix`; bootstrap installs it.

### Phase G (roadmap, not v1) — Keychain
- Add `KeychainProvider` (macOS `security` CLI) implementing `SecretProvider`; introduce the `sc-mcp`
  launcher; flip the generator from "substitute literals" to "emit `sc-mcp` reference"; migrate
  existing `secrets.json` values into the keychain and remove on-disk plaintext.
**Exit:** no plaintext secret on disk; behavior otherwise unchanged.

### Phase H — Dashboard / command center (doc 16)
Turns the app into a scope-aware command center; the wizard becomes Catalog/Add. Slices:
- **H1 — Scope + inventory:** scope selector (Workspace default when a folder is open, else Global);
  `core/inventory.ts` reads installed agents/skills from the scoped `.kiro`; `core/lockfile.ts`
  written on install; webview shell with nav (Overview/Agents/Catalog/Environments/Connections/
  Status) + scope dropdown; Overview + Agents list/detail (skills, installed/available).
- **H2 — Update detection:** coarse (lockfile `ref` vs latest tag) then per-object via git-blob-sha
  vs GitLab tree ids; per-agent/skill update flags + "what changed."
- **H3 — Recent activity:** `core/sessions.ts` reads `~/.kiro/sessions/cli/*.json` metadata,
  scope-filtered by `cwd`; metadata-only feed. Spike: locate the agent field for per-agent
  attribution; IDE sessions later.
**Exit:** opening the dashboard in a workspace shows that workspace's agents + status; the dropdown
switches to Global; updates are flagged; a recent-activity feed renders. Headless tests for
inventory, lockfile, update-diff, and session parsing.

---

## 7. Testing strategy
- **Headless unit tests (node)** for every `core/*`: manifest parse/validate, dependency resolution,
  planner file lists, **generator substitution** (assert values present + zero `${VAR}` remaining),
  registry CRUD + secret-field rejection, secretsStore round-trip + `0600`, steering generation,
  lockfile diff.
- **Schema fixtures** (valid/invalid) for all four schemas; assert environments schema rejects secret
  fields.
- **Generator golden files** for developer/atlas/jarvis configs (CLI `.json` + frontmatter).
- **Manual Kiro checklist** per phase: activation, views render, wizard completes, MCP launches with
  substituted secrets, registry label resolution, secret rotation, verify dashboard, uninstall.
- **macOS-only** target (per audience); add Linux later only if needed.

---

## 8. Acceptance criteria (overall DoD)
- J1–J6 (doc 13 §4) pass on macOS.
- Install/update/rotate require **zero** manual file editing.
- A generator unit test + a CI grep gate assert **no `${VAR}` remains** in generated configs and the
  **environment registry contains no secrets**.
- `secrets.json` and generated configs are `0600` + gitignored.
- `.vsix` builds in CI and installs privately via the bootstrap script; headless suite green; golden
  files reviewed.

---

## 9. Risks & mitigations
| Risk | Likelihood | Mitigation |
|---|---|---|
| Kiro doesn't pass the literal `env` block through to the docker MCP as expected | Low/Med | **Phase D first task: prove it** — generate a config with a literal `GITLAB_TOKEN` for Atlas and confirm the MCP authenticates in Kiro before building the UI. |
| Secret leaks into the repo or a committed file | Low | `environments.json` schema rejects secrets; `secrets.json`+configs gitignored; CI grep gate. |
| Agent doesn't reliably read the registry by label | Med | Steering enumerates labels + explicit "read this by label" instruction; verify with a scripted prompt in the manual checklist. |
| Kiro API drift breaks views | Low/Med | Conservative engine floor + compatibility self-check (L1). |
| Plaintext posture concerns | Med | Documented in-app; keychain roadmap (Phase G) behind the `SecretProvider` seam. |

---

## 10. Sequencing, effort, parallelization
- **Critical path:** A → B → C → **D** → E → F. (G is post-v1 roadmap.)
- **Parallelizable:** webview components (B/C/D UI) alongside `core/*` once the message protocol
  (Phase A) is fixed. Two tracks: *UI* and *core/generator*.
- **Rough effort (1 eng):** A ≈ 2–3d, B ≈ 2d, C ≈ 2d, D ≈ 3–4d, E ≈ 2–3d, F ≈ 1–2d → ~2–3 weeks.

---

## 11. Migration from the POC
- Keep `gitlab.ts`, `envkeys.ts`, `installer.ts` (→ `core/planner.ts`), the smoke test, the
  activity-bar/engine fixes.
- Replace single-page `panel.ts` HTML + `media/main.js` with the Preact app (Phase A).
- **Remove the `.env` bridge** in `secrets.ts`; replace with `secretsStore.ts` + the substitution
  generator (Phase D).
- No change to `.kiro/` **content** — only how it's installed/wired.

---

## 12. First concrete tasks (ready to start)
1. Add esbuild + Preact + ajv; stand up the app shell + nav (Phase A).
2. Replace install-target radios with selectable cards + folder picker (fixes the reported bug).
3. Author the four JSON Schemas in `schemas/` + wire ajv in `core/manifest.ts`.
4. **Phase D probe (do early):** generate an Atlas sub-agent config with a literal `GITLAB_TOKEN`
   substituted in and confirm the MCP authenticates in Kiro — proving the substitution model before
   building the secrets UI on it.
