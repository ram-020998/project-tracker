# Glossary

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · arc42 section 12

Terms used across the Genesis code and these documents, in alphabetical order. Where a term has a code name, it
is shown in `code`.

| Term | Meaning |
|---|---|
| **ACP (Agent Client Protocol)** | The JSON-RPC 2.0 protocol, over stdin/stdout, that Genesis uses to drive `kiro-cli acp`. See [modules/kiro-agent-sdk.md](modules/kiro-agent-sdk.md). |
| **ADR** | Architecture decision record: a numbered, binding decision (for example ADR-012). |
| **Agent step / agent node** | A workflow step that is one narrow Kiro turn, built with `kiro_node`. |
| **AgentProvider** | The interface an agent node calls to run a turn; the default is Kiro over ACP (ADR-051). |
| **apwt** | The `playwright-appian` command-line tool that opens browser sessions, records and replays tests against an Appian site. |
| **Application** | An Appian application tracked in Genesis, identified by its `app_uuid`. |
| **Artifact** | A file on a run's blackboard, recorded in state as name → path. Also: the HTML document a feature stage produces. |
| **Artifacts root** | The folder holding every run's blackboard: `~/Genesis/runs/` or `GENESIS_ARTIFACTS_DIR`. |
| **Blackboard** | One run's folder, `<artifacts root>/<workflow_id>/<run_id>/`, where all bulk data for the run lives. `RunWorkspace` in code. |
| **Bundle (KB)** | A group of Appian objects reachable from one entry point, computed by the parser. |
| **Canonical event** | One of the fixed event kinds stored in `run_events` (`run.started`, `node.completed`, `agent.*`, `validator.result`, `retry.scheduled`, `gate.awaiting`, `gate.resolved`, `run.final`, `error`, `telemetry`, `custom`). |
| **Change request (CR)** | The only way to change a locked spec: chat drafts it, program code applies its plan (ADR-076). |
| **Checkpoint** | LangGraph's saved state after a superstep, stored in `genesis.db`. A run resumes from its latest checkpoint. |
| **Copilot mode** | A chat mode that may start runs, answer gates and cancel runs, each only after the user confirms (ADR-033). |
| **`CORE_MAJOR`** | The compatibility key of `genesis-core` (currently 1). A workflow library built for another major is refused (ADR-019). |
| **Credits** | Kiro's metered usage for a turn or message, with a provenance of `metered`, `partial` or `unavailable` (ADR-032). |
| **Curated tier / custom tier** | The two layers of the MCP and CLI registries: curated entries come from the library and change by merge request; custom entries are the user's own (ADR-029). |
| **Dev environment** | The one Appian environment marked Dev: the source of KB syncs and the target of Implementation (ADR-048, ADR-082). |
| **Escalation gate** | The gate a reliability trio routes to when retries are used up. |
| **Event bus** | The in-memory, per-run fan-out of new events to live subscribers. Not durable. |
| **Event log** | The durable `run_events` table: the source of truth for a run's history. |
| **Feature** | A unit of product work inside an application, with its own stage workspace. |
| **Finalizer** | App-side code that turns a finished run into a domain record (a stage artifact, test results, a lane move). It reacts to events and also reconciles at startup and on read. |
| **Fork** | Start a new run from a past checkpoint of another run, optionally with edited state. The original is untouched (ADR-025). |
| **Gate** | A designed pause where a person decides: kinds `approval`, `escalation`, `pre_mutation`, `review`. `hitl_gate` in code. |
| **Gate descriptor** | What a waiting gate shows: node, kind, prompt, options, context references, time raised. |
| **`genesis.db`** | The main SQLite database, `~/.genesis/genesis.db`. |
| **Genesis Hub** | An Appian application in the dev environment that teammates' Genesis instances use to share a defined subset of data (ADR-064). |
| **`GNS_` id** | The global, monotonic id of a finalized or created story, for example `GNS_000123` (ADR-072). |
| **Healing tier** | The second reliability tier: verify an assembled artifact, then patch it or restart once, then escalate (ADR-067). |
| **HITL** | Human in the loop: gates, pause and resume, state editing and fork (ADR-009). |
| **KB (knowledge base)** | The local, code-free model of each Appian application: objects, dependencies, bundles, business map. Never SAIL source (ADR-037). |
| **`KB_FORMAT_VERSION`** | The parser's output format version; a lower recorded value forces a full KB sync. |
| **Kiro / `kiro-cli`** | The AI agent runtime Genesis drives; installed and signed in by the user. |
| **Lane** | A column of a Workbench board: To Do, Design, Design Review, Implementation, Code Review, Deployment, Verification, Done. |
| **Lesson (L-NNN)** | A recorded mistake that must not happen again. |
| **Library** | The `genesis-workflows` repo and its installed copy under `~/.genesis/library/`. |
| **LifecycleService** | The single authority for every status change of a spec, stage, story or test item (ADR-050). |
| **Lockfile** | `~/.genesis/installed.lock.json`: which workflows and skills are installed, at which ref, and the library's core major. |
| **Managed-native** | An MCP server or CLI that Genesis installs locally into a versioned folder and launches itself (Dev MCP, DevOps MCP, `gws`, `sail`). |
| **MCP** | Model Context Protocol: the standard by which tool servers offer tools to an agent. |
| **META** | The static dict in a workflow's `graph.py` (id, version, inputs schema, retry and healing settings, …), mirrored by `workflow.yaml`. |
| **Object Wiki** | The append-only change history of each Appian object, with links to stories and tests (ADR-070). |
| **Observer** | A callback registered on the run manager that sees every canonical event. |
| **Orphaned run** | A run left `running` after the app process that owned its worker stopped. Failed at the next startup. |
| **`PlatformContext` (`ctx`)** | Everything a workflow node may use at run time, injected by the engine. |
| **`PlatformState`** | The small, editable LangGraph state shape every workflow extends. |
| **Program step / program node** | A deterministic Python workflow step, built with `program_node`. |
| **Provenance** | Where a credit figure came from: `metered`, `partial` or `unavailable`. |
| **QA environment** | The single Appian environment where all test execution and agent browser sessions run (ADR-082). |
| **Reliability trio** | Agent step + validator + retry and escalation. Required for every agent step (ADR-011). |
| **Reports origin** | The second loopback listener (app port + 100) that serves Playwright reports (ADR-085). |
| **Run** | One execution of a workflow. Id `r-<12 hex>`. |
| **Run-owner lock** | `~/.genesis/run/runs.lock`, held by the app process allowed to fail orphaned runs. |
| **SecretProvider** | The secret store, `~/.genesis/secrets.json` (mode 0600), with keys `<scope>/<VAR>`. |
| **Skill** | A `SKILL.md` package of instructions for a standalone activity, run by Kiro in chat or provisioned into a workflow step (ADR-034, ADR-069). |
| **Stage** | One container in a feature workspace: Spec, UX Design, Technical Design, Feature Breakdown, Test Design. Each has its own lifecycle (ADR-056). |
| **Story** | A finalized, editable backlog item of a feature, shown on the Workbench. |
| **Superstep** | One LangGraph execution step; a checkpoint is written after each. |
| **`TC-` / `TS-` / `TE-` / `ACT-` / `DS-`** | Ids of test cases, test scenarios, test executions, library actions and data setups. |
| **Test workspace** | The per-application git repository of test code under `~/.genesis/testing/apps/<app>/` (ADR-081). |
| **Tool-output store** | `<run>/_toolcalls/`: every tool result of an agent session, so big results can be saved by reference. |
| **Trust** | The tools Kiro may run without asking; in chat, the only tools that run at all. |
| **Validator** | A program check of an agent's output: `validator_node` with a `check_fn` returning `ValidationResult`. |
| **Worker** | The child process `python -m genesis.runs.worker` that runs one operation of a run's graph (ADR-012). |
| **Workbench** | The per-application Kanban boards over finalized stories (ADR-061). |
| **Workflow** | A staged, deterministic LangGraph graph packaged as a folder with `workflow.yaml` and `graph.py`. |
