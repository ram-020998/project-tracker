# 2. Constraints

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · arc42 section 2

A constraint is a rule the design must follow, whether or not it is the choice we would make today. Changing one
needs a new architecture decision, not just a code change. Each row gives the reason and the decision record
(ADR) that sets it.

## 2.1 Technical constraints

| Constraint | Reason | ADR |
|---|---|---|
| Python 3.13 for the backend, the libraries and every workflow | One language for engine, nodes and workflows; 3.13 is the pinned runtime | ADR-017, ADR-024 |
| **LangGraph** is the workflow engine, used as a library | It owns control flow, checkpoints and human-in-the-loop interrupts | ADR-001, ADR-023 |
| **FastAPI** embeds LangGraph; there is no LangGraph Server | One local process serves the API, the UI and run control | ADR-023 |
| The engine is async: `ainvoke`/`astream` with `AsyncSqliteSaver` | The synchronous saver fails under async execution (L-009) | ADR-024 |
| **SQLite** for all durable data (`~/.genesis/genesis.db`, WAL mode) | A local single-user app needs no server database; Postgres only on an explicit trigger | ADR-030 |
| Agent memory in a separate SQLite file (`~/.genesis/memory.db`) | Keeps the runs plane untouched; memory can move later on its own | ADR-054 |
| **React + TypeScript** single-page app, served by the same backend | A local single-user web UI | ADR-026 |
| Web stack: Tailwind, shadcn/Radix primitives, React Router, TanStack Query, React Flow | Reuse one established stack and the design tokens | ADR-027, ADR-055 |
| Every backend endpoint is under `/api`; the client adds the prefix centrally | API and SPA routes never collide; deep links work | ADR-028 |
| The AI agent is **Kiro**, run as `kiro-cli acp` and driven over ACP by `kiro-agent-sdk` | The SDK is the only code that talks to the agent runtime | ADR-002, ADR-016 |
| Agent steps depend on the `AgentProvider` interface, not on the Kiro client directly | A second agent provider would be an adapter, not a rewrite | ADR-051 |
| MCP servers are passed to Kiro per agent session over ACP; the user's global Kiro `mcp.json` is never written | Least privilege per step; never mutate the user's own setup | ADR-004, ADR-020 |
| Kiro skills reach a session from the filesystem (`<cwd>/.kiro/skills/`), not over the wire | That is how kiro-cli loads skills (L-024) | ADR-034, ADR-069 |
| The platform is **one repo** with the libraries under `packages/`; one shared version, set by the git tag | One install command and one release flow | ADR-080 |
| A library whose `genesis_core_major` differs from `CORE_MAJOR` (=1) is refused | Workflows built for another core major would break at run time | ADR-019 |

## 2.2 Platform constraints

| Constraint | Consequence |
|---|---|
| Runs on macOS or Linux | POSIX file locks (`fcntl.flock`) guard the run-owner lock; process trees are read from `/proc` or `ps` |
| `kiro-cli` must be installed and signed in | Every agent step and chat message needs it. Sign-in is from Settings or `kiro-cli login` |
| Node.js 20 or newer and Chromium for test execution | Installed per machine from the Testing tab; Chromium lives under `~/.genesis/testing/browsers/` |
| Docker is optional | Only some curated MCP servers (for example `jira`) launch through Docker; the core path does not need it |
| The managed Appian MCP servers are local installs, not containers | The Dev and DevOps MCP servers are unpacked into per-version folders with their own Python environment |

## 2.3 Security and operating constraints

| Constraint | Reason | ADR |
|---|---|---|
| Local, single user, no authentication | Genesis is a personal tool running with the user's own credentials | ADR-003, ADR-026 |
| `genesis serve` and `genesis up` refuse a non-loopback address unless `--i-understand-no-auth` is passed | Without auth, a network bind would expose everything | ADR-026 |
| Playwright reports are served only from a second loopback origin (app port + 100), never from the app's origin | A report page must not be able to call the app's `/api` | ADR-085 |
| Chat is read-only; its mutations are human-confirmed run operations only | An AI answering questions must not change anything by itself | ADR-031, ADR-033 |
| Writes to Appian design objects happen only in the Implementation lane, after one blanket approval, and never delete | Mutating a customer application needs a person's yes | ADR-021, ADR-068 |
| Test execution and agent browser sessions run only on the single QA environment, as the application's test users | Tests change application data; they must never touch development or production | ADR-082 |
| Secrets are stored by key name in the SecretProvider (`~/.genesis/secrets.json`, mode 0600), never in state, logs or `environments.json` | A secret that reaches agent output or a log must be treated as leaked | ADR-048, L-100 |

## 2.4 Organisational constraints

| Constraint | Consequence |
|---|---|
| Internal tool for Appian Solutions staff | Code and the workflow library live on the internal GitLab |
| Workflows come from one shared library repo (`genesis-workflows`) through merge requests | The curated MCP and CLI registries are changed only by merge request; users add their own entries in a separate custom tier (ADR-005, ADR-029) |
| Releases are git tags; the app updates itself to the newest tag | No package registry for the app; `scripts/install-packages.sh` is the one install command (ADR-046, ADR-080) |
| Architecture decisions are binding and recorded | A change that needs a deviation must flag it and get a new or amended decision first |
| Work is done by a small team of role agents (spec, dev, review, release, docs) supervised by one engineer | Every fact has one home; these documents are refreshed by the docs agent after each release (ADR-077) |
