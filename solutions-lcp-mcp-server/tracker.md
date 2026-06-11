# Solutions LCP MCP Server — Project Tracker

> **Session ID:** `ca350ebe-084d-4014-8eed-3a520b611c14` (2026-06-09)

## Overview

This project concerns the `solutions-lcp-mcp-server` — an MCP (Model Context
Protocol) server that exposes Appian's LCP (Low-Code Platform) design-time APIs
as agent-callable tools (creating/managing applications, record types, record
data, interfaces, process models, integrations, etc.).

There are two implementations involved:

1. **Our tool** — `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-lcp-mcp-server`
   A hand-written, lean implementation we developed. Distributed as a single
   Docker image (`docker pull` + `docker run -i`), easy for users to consume
   and update.

2. **The new tool / bundle** — `/Users/ramaswamy.u/Downloads/lcp-mcp-server-bundle`
   Appian's official, production-grade implementation. Far more capable
   (~125–130 tools, generated SDKs, multi-tenant auth, multiple transports) but
   with a complex local setup (download, run, configure, manual updates).

The objective of this session: **bring the full capability of the official
bundle into our repo while keeping our simple Docker-based distribution model**,
and document how to keep our copy in sync with future bundle releases.

## Status

Migration COMPLETE and verified locally (Docker build + tool listing + stdio
startup). Update/sync tooling and documentation added. **Not yet committed or
pushed** — awaiting user review. Decision pending on branch vs. `main` and on
disabling FastMCP's startup version check.

---

## Session Log

### 2026-06-09 — Analyze both servers, migrate bundle into our repo (Docker distribution), add upstream-sync tooling/docs

#### Context / how the session unfolded

1. Read and understood the bundle (`lcp-mcp-server-bundle`).
2. Compared it against our `solutions-lcp-mcp-server`.
3. Confirmed the bundle has record-data **write** tools (our tool does not).
4. Explained the key architectural difference: our tool reaches Appian via
   application-level Web API objects; the bundle reaches it via a
   platform-installed plugin + native API.
5. User's pain point: loves the bundle's capabilities but hates its
   distribution/setup/update story; loves our Docker model. Decision: take the
   bundle's contents wholesale into our repo and ship via our Docker image.
6. Executed the migration and verified it.
7. Added a sync script + UPDATING guide so future bundle releases can be pulled
   in mechanically.

#### Project comparison (our tool vs. bundle) — as analyzed

| Dimension | Our tool (`solutions-lcp-mcp-server`) | Bundle (`lcp-mcp-server-bundle`) |
|---|---|---|
| Origin | Hand-written by us | Appian official (`docs.appian.com/suite/help/26.4/devmcp.html`) |
| MCP framework | Raw `mcp` SDK (`mcp.server.Server`) | `fastmcp` (`@mcp.tool` decorators) |
| API access | Hand-written `httpx` client (`client.py`) | Generated SDK clients |
| Tool count | 18 tools, 6 domains | ~125 tools (verified), ~21 domains |
| Transport | stdio only | stdio + HTTP/SSE + JSON-RPC (uvicorn) |
| Auth | Basic Auth only, single-tenant (read at startup) | Basic Auth + Bearer/JWT, per-request, multi-tenant |
| Python | 3.11 (old Dockerfile) | 3.13+ |
| Deployment | Single Docker image, env-var config | Multi-package bundle, server-hosted |

**Our tool's 18 tools (6 domains):** applications (list/get/create), record
types (list/get/create/update), interfaces (list/get/create/update), expression
rules (list/get/create/evaluate), constants (list/create), objects
(searchObjects, getObjectDependencies).

**Bundle domains (21):** ai_agents, ai_skills, applications, connected_systems,
constants, documents, expression_rules, folders, groups, integrations,
interfaces, objects, process_models, record_data, record_types, robotic_tasks,
sites, test_rule, validation, web_apis. Largest files: `record_types.py` (~66KB),
`process_models.py` (~21KB).

#### Key technical findings (the "why" behind decisions)

**1. Record data write capability (bundle has it; our old tool did not).**
Bundle `src/lcp_mcp_server/tools/record_data.py` exposes 4 tools:
- `listRecordData` (GET) — reads rows as CSV, paginated (limit/offset).
- `insertRecordData` (CREATE) — writes new rows from CSV; returns assigned PKs.
- `updateRecordData` (UPDATE) — updates rows by PK; supports partial updates.
- `deleteRecordData` (DELETE) — deletes rows by PK.
CSV format rules baked into tool descriptions: header names must match record
field names exactly; PK column may be omitted on insert for auto-gen keys;
booleans as `1`/`0` (NOT `"true"`/`"false"`); dates `YYYY-MM-DD`; datetimes
`YYYY-MM-DD HH:MM:SS` or ISO `T`; times `HH:MM:SS`; all interpreted as UTC;
RFC 4180 quoting for commas/quotes/newlines; no embedded JSON. Backed by plugin
SDK ops `insert_record_type_data` / `update_record_type_data` /
`delete_record_type_data`, wrapping CSV in a small `_CsvBody` byte payload.
This writes to the record type's **source data** (underlying data store/table).

**2. How the bundle reaches the environment WITHOUT application endpoints.**
- Our tool config: `api_path = "/suite/webapi/lcp-api"` — the `/suite/webapi/`
  namespace is served by **Web API design objects** built/deployed INSIDE an
  Appian application. So our server is a client of OUR application's endpoints,
  which must be installed in each environment.
- Bundle uses two namespaces, neither an application object:
  - `/suite/rest/a/lcp-api/latest` (default `LCP_API_PATH`) — served by an
    **installed Appian plugin** (the "LCP API plugin") registering native REST
    endpoints at the platform level. Confirmed via grep:
    `config.py:26` and `dynamic_client.py:34`.
  - `/suite/lcp/api` — a **native platform/beta API** (used for AI skills,
    agents, robotic tasks via Bearer/JWT). Confirmed: `config.py:36`,
    `dynamic_client.py:99`.
- Strong evidence it's a versioned plugin: bundle `tools/__init__.py`
  `handle_tool_error` treats **HTTP 501** as the plugin router's signal that an
  operation's route isn't registered on the installed plugin version, and
  returns a message telling the user to "ask an admin to upgrade the plugin."
- Consequence: bundle requires the LCP API plugin installed in the target
  environment (no per-app Web API deployment). This is likely the very reason
  our original tool used the Web API route.

**3. Per-request / multi-tenant auth (bundle).**
`dynamic_client.py` defines `DynamicLCPClient` (wraps plugin client) and
`DynamicBetaClient` (wraps beta client). They override base_url and auth token
PER REQUEST, resolved from a per-request `callback_url` + Bearer token via
ContextVars (`shared_mcp_utils/jsonrpc.py`) or FastMCP HTTP headers
(`x-callback-api-url`). JSON-RPC calls isolated per `appUuid` using
`contextvars.Context` (LRU bounded to 128) so naming-prefix state can't leak
between applications. Plugin client uses Basic Auth from
`LCP_USERNAME`/`LCP_PASSWORD`; beta client uses per-request JWT.
`LCP_REQUIRE_CALLBACK_URL=true` makes a missing callback_url a hard error;
otherwise it falls back to config base_url with a warning.

**4. Bundle transports (`sse_server.py`).** Starlette app via uvicorn exposing:
`/health`, `/jsonrpc` (POST, for Appian AIP Agents API tool execution),
`/internal/sse` (internal MCP, sub-agents only), `/sse` (external, mounted at
`/` and optional `MOUNT_PREFIX`). stdio entry is `__main__.py` →
`mcp.run(transport="stdio")`. Default port 8003 (`LCP_MCP_PORT`).

**5. Bundle packaging.** Root `pyproject.toml`: setuptools build, Python ≥3.13,
deps: `fastmcp>=2.0.0`, `httpx>=0.27.0`, `pydantic>=2.0.0`,
`pydantic-settings>=2.0.0`, `uvicorn>=0.30.0`, plus 4 local packages via
`[tool.uv.sources]` (editable):
- `composer-logging` → `lib/composer_logging` (setuptools; structured logging,
  redaction)
- `shared-mcp-utils` → `lib/shared_mcp_utils` (hatchling; jsonrpc handler,
  client utils)
- `lcp-api-plugin-client` → `sdk/lcp-api-plugin-client` (poetry-core; version
  **1.0.73**; "LCP API Plugin" client; Basic Auth)
- `lcp-api-beta-client` → `sdk/lcp-api-client` (poetry-core; version
  **2026.1.19**; "LCP Agent Studio API (Subset)"; Bearer/JWT)
Dev extras: pytest, pytest-asyncio, pytest-cov, hypothesis,
datamodel-code-generator, pyyaml.

#### Decisions Made

- **Adopt the bundle wholesale (vendor it), wrap in our Docker distribution.**
  Reason: the ~125 tools are thin wrappers over generated SDKs; hand-porting
  would be weeks of error-prone work that immediately drifts from Appian's
  official version. Vendoring keeps us in sync and low-maintenance.
- **Keep stdio entry point as the Docker entrypoint.** Reason: preserves our
  existing `docker run -i` consumption model exactly (MCP client launches the
  container; updates via `docker pull`).
- **Replace (not keep) the old hand-written code.** Reason: user wants exactly
  what the bundle has; keeping both is ambiguous. Old code preserved in git
  history (working tree was clean before changes → reversible).
- **Use `uv` in the Docker build.** Reason: it understands the bundle's
  `[tool.uv.sources]` local editable packages; pip would not resolve the local
  package names. `uv pip install --system .` installs everything cleanly.
- **Bump base image to python:3.13-slim.** Reason: bundle requires Python ≥3.13
  (our old Dockerfile was 3.11).
- **Add two pyproject sections the bundle lacks:** `[project.scripts]`
  (`lcp-mcp-server = "lcp_mcp_server.__main__:main"`) and
  `[tool.setuptools.packages.find]` (`where = ["src"]`). These are the ONLY
  deltas vs. the bundle's pyproject (confirmed by diff). Must be preserved on
  every future sync.
- **Vendoring model for updates:** never hand-edit `src/`, `lib/`, `sdk/`;
  they are overwritten wholesale on each sync. Behavior changes belong upstream
  in the bundle.

#### Completed — exact changes made to `solutions-lcp-mcp-server`

Copied in (vendored, excluding `__pycache__`, `.ruff_cache`, `.DS_Store`):
- `src/`  (was bundle `src/` — `lcp_mcp_server/` package + egg-info)
- `lib/`  (composer_logging, shared_mcp_utils)
- `sdk/`  (lcp-api-plugin-client, lcp-api-client)

Removed (superseded; preserved in git history):
- `lcp_server/` (old hand-written package: server.py, client.py, config.py,
  models.py, utils.py, tools/)
- `main.py` (old asyncio stdio entry point)
- `tests/` (old `test_server.py` targeting the old server)
- `requirements.txt` (was `httpx>=0.27.0`, `mcp>=1.0.0`) — pyproject is now
  source of truth
- `requirements-dev.txt` (was pytest, pytest-asyncio)

Created / rewritten:
- `pyproject.toml` — NEW root project file. Mirrors bundle deps + uv.sources;
  adds `[project.scripts]` and `[tool.setuptools.packages.find] where=["src"]`.
- `Dockerfile` — NEW. `python:3.13-slim`; copies `uv` from
  `ghcr.io/astral-sh/uv:latest`; `ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
  UV_LINK_MODE=copy`; copies pyproject + lib/ + sdk/ + src/; runs
  `uv pip install --system --no-cache .`; `ENTRYPOINT ["python", "-m",
  "lcp_mcp_server"]` (stdio).
- `.dockerignore` — NEW. Excludes `__pycache__`, `*.pyc`, `.ruff_cache`,
  `.pytest_cache`, `*.egg-info`, `.git`, `.venv`, `.env`, `.DS_Store`, `docs/`.
- `.env.example` — updated: LCP_URL/USERNAME/PASSWORD + commented
  `LCP_API_PATH=/suite/rest/a/lcp-api/latest`.
- `.gitlab-ci.yml` — updated: lint+test images bumped to `python:3.13-slim`;
  lint now `flake8 src/ tests/ --max-line-length=120 --ignore=E501,W503`;
  test job uses `pip install uv` then `uv pip install --system ".[dev]"` then
  `python -m pytest tests/ -v --tb=short`. build-image job (kaniko →
  `${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}` and `:latest`, on `main`)
  unchanged.
- `pytest.ini` — `testpaths = tests`, `python_files = test_*.py`,
  `asyncio_mode = auto`.
- `tests/__init__.py` — NEW (empty).
- `tests/unit/test_smoke.py` — NEW. Builds server with
  `LCPConfig(lcp_url="https://example.appiancloud.com")`, asserts >50 tools and
  presence of `listApplications`, `createApplication`, `insertRecordData`.
- `README.md` — rewritten around the Docker pull/run -i stdio model, with:
  prerequisites (LCP plugin must be installed; 501 → upgrade plugin), quick
  start, MCP client JSON config example, config table, auth caveat note
  (ai_skills/ai_agents/robotic_tasks need Bearer JWT), tools-by-domain list,
  development section, repo layout, local build, and an "Updating from the
  upstream bundle" section linking to docs/UPDATING.md.
- `scripts/sync-from-bundle.sh` — NEW, executable (chmod +x). Takes bundle path
  arg; validates it has src/lib/sdk; replaces src/lib/sdk; strips caches; diffs
  bundle vs our `[project].dependencies`; prints post-sync checklist. Verified
  working (reported "no dependency differences" against current bundle).
- `docs/UPDATING.md` — NEW. Vendored-vs-ours table; golden rule (don't hand-edit
  src/lib/sdk); the two pyproject additions to preserve; step-by-step sync
  process (get bundle → run script → reconcile deps → check SDK version bumps →
  rebuild → verify tool count → test → commit/tag/push); troubleshooting.

#### Commands run & key outputs

- `docker --version` → Docker 28.0.2. `uv --version` → uv 0.10.4 (Homebrew).
  `git status` → clean, `main` tracking `origin/main`.
- `docker build -t solutions-lcp-mcp-server:test .` → SUCCESS. Installed local
  packages confirmed: `composer-logging`, `shared-mcp-utils==0.1.0`,
  `lcp-api-plugin-client`, `lcp-api-beta-client`. Notable resolved versions:
  pydantic 2.13.4, pydantic-settings 2.14.1, uvicorn 0.49.0, starlette 1.2.1,
  fastmcp deps, pyjwt 2.13.0.
- Tool-listing run inside image (`--entrypoint python ... list_tools`) →
  **TOOL_COUNT: 125**, including `insertRecordData`, `updateRecordData`,
  `deleteRecordData`, and full CRUD across applications, record types/fields/
  views/relationships/actions/user-filters, interfaces, process models/nodes,
  groups/members, documents, folders, connected systems, integrations, sites,
  web APIs, constants, expression rules, ai skills/agents, robotic tasks,
  validation, test rule, object security.
- stdio entrypoint smoke run (`echo "" | docker run --rm -i -e LCP_URL=... ...`)
  → server logs "Starting LCP MCP Server", "Base URL:
  https://example.appiancloud.com/suite/rest/a/lcp-api/latest",
  "Plugin Client Auth: Basic Auth", "initialization complete", then FastMCP
  banner. Exit 141 = SIGPIPE from `head` closing pipe (not an error).
  OBSERVATION: FastMCP makes a startup HTTP call to
  `https://pypi.org/pypi/fastmcp/json` (version check) — network dependency at
  launch; consider disabling for production.
- `scripts/sync-from-bundle.sh <bundle>` → ran clean; "no dependency
  differences".
- `diff bundle/pyproject.toml ours` → only additions are `[project.scripts]`
  and `[tool.setuptools.packages.find]`.

#### Learnings

- The bundle is "thin tool wrappers over generated SDKs," so vendoring + Docker
  packaging is a distribution problem, not a code-rewrite problem.
- `[tool.uv.sources]` is uv-specific; plain pip won't resolve the local package
  names → Docker build must use `uv` (or install each local path explicitly).
- With src layout + setuptools, `[tool.setuptools.packages.find] where=["src"]`
  is needed (the bundle relied on uv editable install which sidesteps this).
- MCP over stdio in Docker works via `docker run --rm -i` launched by the MCP
  client; server exits cleanly on stdin EOF.
- The `/suite/webapi/` vs `/suite/rest/a/` distinction is the crux of why the
  two tools differ operationally (app-deployed Web API objects vs. a
  platform-installed plugin).

#### Issues Encountered

- (Process) Two assistant responses timed out while composing long messages.
  No file corruption; work was intact. Mitigation: split work into smaller
  steps. No code impact.

#### Caveats / Known Limitations (carry forward)

- **Plugin prerequisite:** the image talks to `/suite/rest/a/lcp-api/latest`,
  which requires the LCP API plugin installed in the target environment.
  Dockerizing does NOT remove this requirement. Missing/old plugin → HTTP 501.
- **Bearer-token domains in stdio:** `ai_skills`, `ai_agents`, `robotic_tasks`
  use the beta API needing a per-request JWT (normally from the callback flow).
  Plain stdio + Basic Auth does not supply it → those specific tools may not
  authenticate. All Basic-Auth (plugin) domains work.
- **FastMCP startup version check** hits pypi.org — consider disabling for
  production (avoid network dependency at launch).

#### Remaining Items / Next Steps

- [ ] Decide: commit changes on a branch vs. directly on `main`; then commit
      with a message noting bundle adoption + SDK versions (plugin 1.0.73,
      beta 2026.1.19).
- [ ] Decide whether to disable FastMCP's startup version check (and implement
      if yes).
- [ ] Optional: address Bearer/JWT auth for ai_skills/ai_agents/robotic_tasks
      if those domains are needed in the stdio/Docker single-tenant model.
- [ ] Optional: consider also shipping the SSE/JSON-RPC transport if Appian AIP
      Agents integration is wanted (currently stdio-only by design).
- [ ] Push; CI (`.gitlab-ci.yml`) builds and publishes the image; consumers
      update via `docker pull`.
- [ ] Confirm the LCP API plugin is installed in target environment(s) before
      rollout.

#### Reference paths

- Our repo: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-lcp-mcp-server`
- Bundle: `/Users/ramaswamy.u/Downloads/lcp-mcp-server-bundle`
- Appian setup docs (bundle INSTALL.txt):
  `https://docs.appian.com/suite/help/26.4/devmcp.html`
- Update guide: `docs/UPDATING.md`; sync script: `scripts/sync-from-bundle.sh`

---

### 2026-06-09 — Fix CI lint failure (vendored code) — session `ca350ebe-084d-4014-8eed-3a520b611c14`

**Problem:** CI lint stage failed. Reproduced with
`flake8 src/ tests/ --max-line-length=120 --ignore=E501,W503` → 4 errors, all in
**vendored** bundle code:
- `src/lcp_mcp_server/tools/__init__.py:10:1 F401` 'lcp_api_plugin_client.types.UNSET' imported but unused
- `src/lcp_mcp_server/tools/__init__.py:21:9 F811` redefinition of unused 'UNSET' from line 10
- `src/lcp_mcp_server/tools/process_models.py:28:1 F401` ...FormConfig imported but unused
- `src/lcp_mcp_server/tools/process_models.py:35:1 F401` ...ProcessModelVariable imported but unused

**Root cause:** our CI was linting `src/`, but `src/` is vendored upstream code
we've committed not to hand-edit (overwritten on every sync; upstream lints with
ruff, not flake8). Fixing in place would be lost on the next sync.

**Fix (consistent with the vendoring model — lint only code we own):**
- Added `.flake8` config: `max-line-length=120`, `extend-ignore=E501,W503`,
  `exclude = .git,__pycache__,.venv,.ruff_cache,.pytest_cache,*.egg-info,src,lib,sdk`.
- Changed `.gitlab-ci.yml` lint command from
  `flake8 src/ tests/ --max-line-length=120 --ignore=E501,W503` to `flake8 .`
  (config now drives settings + excludes).
- Updated `docs/UPDATING.md`: added `.flake8` to the ownership table and a
  "Linting" note explaining vendored dirs are excluded (don't fix nits in
  vendored code).

**Verification:**
- `uvx flake8 .` → exit 0, no output (clean).
- Probe test: added `tests/unit/_probe.py` with an unused import → flake8
  reported `tests/unit/_probe.py:1:1 F401`, proving `tests/` is still linted;
  removed probe; re-ran → clean. Confirms excludes apply to vendored dirs only.

**Env note:** system python (3.14, homebrew) has no flake8 and pip is
externally-managed; used `uvx flake8` to run.

**Files changed:** `.flake8` (new), `.gitlab-ci.yml`, `docs/UPDATING.md`,
this tracker. Still uncommitted.

---
