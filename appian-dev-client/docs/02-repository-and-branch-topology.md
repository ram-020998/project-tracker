# 02 — Repository & Branch Topology

All of this lives in **one** GitLab repository:

```
git@gitlab.appian-stratus.com:appian/dev/composer.git
```

The branching-and-isolation product is **not on `main`**. It is developed on a family of
long-lived feature branches. `main` is a different product (the Composer unified-chat
platform). Understanding which branch holds what is essential before reading any code.

## The three branch lines

| Line | What it is | How to recognize it |
|---|---|---|
| `origin/main` | **Composer** — the unified-chat / Sessions-API product (dev-copilot, message handlers, etc.) | no `go.work`, no `devmcp-local` |
| `origin/dev-mcp` (+ `dev-mcp-*`, `DMPD-*`) | **DevMCP "classic"**: Java `lcp-api-plugin` + Python `lcp-mcp-server` + `sail-cli`. Agents edit **directly** against the shared Appian dev server. | ~171 Go files (only `sail-cli`); no `devmcp-local`, no `appian-expr` |
| `origin/appian-dev` (+ `appian-dev-*`) | **DevMCP Local** = the branching/isolation product. Everything `dev-mcp` has **plus** the Go modules `appian-expr`, `appian-session`, `devmcp-local`. | ~2,995 Go files; `go.work`; `DEVMCP-LOCAL-AND-VISUALIZATION-DESIGN.md` |

### How they relate

- `appian-dev` is built **on top of** the `dev-mcp` line and continuously **absorbs** it.
  Example merge commit observed on `appian-dev`:
  `"Merge branch 'sync-dev-mcp-2026-11-03' into 'appian-dev'"`.
- `DMPD-*` branches are discrete feature tickets on the `dev-mcp` line. Example:
  **DMPD-423 "type-vocabulary"** (commit `dc84574e`) added support for the **Decision**
  (decision table) design-object type end to end — OpenAPI schema, Java `DecisionHandler`,
  Python MCP tools, skill docs, plugin-factory test suites. These land on `dev-mcp` and are
  later synced up into `appian-dev`.

### `service-components/` difference (the tell)

```
dev-mcp:     composer-chat  developer-copilot(-ui)  lcp-api-plugin  lcp-mcp-server
             planning-mcp-server  process-model-mcp-server  sail-cli  sail-mcp-server  shared  ui-prototype

appian-dev:  (everything above) + appian-expr  + appian-session  + devmcp-local
```

## Where the branching feature lives (on `origin/appian-dev`)

| Path | Role |
|---|---|
| `service-components/devmcp-local` | The Go **local server** — the whole branch model, checkout, merge, drift, render, CLI |
| `service-components/appian-expr` | The **expression runtime** (SAIL AST, local eval), the `branchfile` strip/restore package, the interface sandbox render support |
| `service-components/appian-session` | The **shared session cache** (cookie/CSRF format) shared with the Python MCP server |
| `service-components/lcp-api-plugin` | The **Java plugin** installed on the Appian environment that serves the REST API |
| `service-components/lcp-mcp-server` | The Python MCP server + `lcp-login` / `browser_auth.py` session capture |
| `go.work` | Ties `appian-expr`, `appian-session`, `devmcp-local`, `sail-cli` into one Go workspace |
| `DEVMCP-LOCAL-AND-VISUALIZATION-DESIGN.md` | Design decisions & milestones (note: describes an intended TS server; the shipped server is Go) |

The Go workspace's four modules:

- **`sail-cli`** → `./cmd/sail` = the strategy deck's **SAIL CLI**
- **`devmcp-local`** → `./cmd/appian-dev` = the deck's **local MCP server (Go)** and the `appian-dev` binary
- **`appian-expr`** (incl. `branchfile/branchfile.go`) = expression engine + the on-disk branch identity mechanics
- **`appian-session`** = cached Appian credential/session shared between Go tools and the Python MCP server

## Working with these branches locally

The checkout is large. To explore a branch without disturbing `main`, use a **git worktree**:

```bash
cd ~/repo-gitlab/appian/composer
git fetch origin
git worktree add -f /tmp/composer-appian-dev origin/appian-dev
# ... explore /tmp/composer-appian-dev ...
git worktree remove /tmp/composer-appian-dev   # when done
```

## Deployed vs. source

The plugin **deployed** on a given environment may be older than `origin/appian-dev`. The
live test environment (`merge-assist-dev`) ran plugin **v26.6.110**, which predates the
`manifest` and `objects/batch` routes. Always treat the deployed `GET /meta` version as
ground truth for which endpoints exist — see
[`09-live-environment-findings.md`](09-live-environment-findings.md).
