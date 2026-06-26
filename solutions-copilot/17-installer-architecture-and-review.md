# 17 — Installer Architecture & Code Review

**Status:** Implemented · **Repo:** `solutions-copilot/installer/` (v0.6.0) · **Last updated:** 2026-06-26

> Code-review outcome and the standard, modular, OOP architecture the installer now follows. Key
> guarantee: **adding a new agent/skill/MCP requires only manifest + repo changes — no extension
> code changes.**

---

## 1. Layered architecture
```
webview/ (Preact)  ──postMessage──▶  app/ (controller)  ──▶  services/ (OOP, DI)  ──▶  core/ (pure) + infra/ (fs/os)
```
- **`core/`** — pure, vscode-free, unit-tested domain logic (manifest, planner, generator,
  secretFields, registry, dashboard, inventory, lockfile, sessions, authoring, steering, gitlab).
- **`infra/`** — filesystem side-effects (writer).
- **`services/`** — single-responsibility classes composing core/infra, wired by dependency
  injection. The stateful, OOP layer.
- **`app/`** — `ConfigPanel`: a thin controller that owns the webview and **routes messages to
  services**; holds no business logic.
- **`webview/`** — Preact UI; talks to the host only via the typed message protocol (`src/messages.ts`).

## 2. Services (composition root in `ConfigPanel`)
| Service | Responsibility |
|---|---|
| `Settings` | Read VS Code configuration (host/project/ref). |
| `ScopeService` | Resolve Global vs Workspace `.kiro`, default scope, folder pick. |
| `SecretsService` | Own the `SecretProvider`; token + fields/cards/value-resolution. |
| `ConnectionService` | GitLab client + manifest/catalog lifecycle; sub-agent list. |
| `EnvironmentService` | Environment registry CRUD + steering delivery. |
| `InstallService` | plan → substitute secrets → write → lockfile → deliver registry → apply custom. |
| `DashboardService` | Assemble per-scope `DashboardData`. |
| `AuthoringService` | Custom agents/skills/MCP. |

Each is independently testable and replaceable. `ConfigPanel` constructs them once (the composition
root) and delegates.

## 3. Code-review findings → resolutions
| Finding | Resolution |
|---|---|
| `ConfigPanel` was a ~340-line **god class** (SRP violation). | Decomposed into 8 services; the panel is now a ~180-line router. |
| **Hardcoded** `GLOBAL_VARS` / `NON_SECRET_VARS` blocked new-agent pickup. | Classification is **manifest-driven** (`globalEnvKeys`, per-MCP `secretKeys`/`publicKeys`) with built-in fallbacks. No hardcoded var lists in logic. |
| Manifest **metadata unused** (no titles/summaries). | `agentMeta` consumed by `toCatalog`; agents are self-describing. |
| Mixed paradigm. | Pure functional `core/` (tested) + OOP `services/` (DI) — clear, standard split. |

## 4. Modularity contract — how to add a new agent (no code change)
1. Add the agent + skills to the **manifest** (`agents.roles`/`agents.intelligence`, `skills.<role>`)
   in the GitLab repo, plus optional `agentMeta[name] = { title, summary }`.
2. If it introduces a new MCP, add an `mcp.<server>` entry with `owner`, `envKeys`, and (recommended)
   `secretKeys`/`publicKeys`; add shared vars to `globalEnvKeys`.
3. Commit the agent's `.kiro/agents/<name>.{json,-prompt.md}` (+ skills) to the repo.

On the next connect, the dashboard automatically: lists the agent (Catalog/Agents), shows its skills,
derives its MCP secret cards with correct secret/global classification, installs it (sub-agents
auto-resolved from its config), and tracks updates. **The extension code does not change.** This is
verified by `test/classification.test.js` (a brand-new agent/MCP classified purely from the manifest).

## 5. Testing
11 headless `core/` tests (run `npm test`): manifest parse/catalog/env-keys, manifest-driven
classification, secret fields + resolution, mcp cards, generator substitution, registry, writer,
inventory, lockfile, dashboard assembler (incl. foreign-agent exclusion), custom authoring. The
webview is typechecked (`npm run typecheck:webview`); host compiled with `tsc`.

## 6. Remaining / next
- Managed-agent **overlays** (custom skills/MCP onto built-in agents, surviving update regen).
- Per-object **update diff** (git-blob-sha vs GitLab tree ids) — H2 in doc 16.
- Per-agent **activity attribution** (session-format spike).
- Optional: move `profileMeta` descriptions fully into the manifest (UI already supports a fallback).
