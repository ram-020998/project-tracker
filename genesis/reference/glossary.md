# Genesis — Glossary

Canonical terms used across the Genesis documentation.

| Term | Definition |
|---|---|
| **Genesis** | The platform: a local web app + LangGraph engine that orchestrates SDLC workflows for the Solutions dept. |
| **Workflow** | A LangGraph package automating one SDLC task (the successor to a solutions-copilot "skill"). Exposes `build()` + `META`. |
| **`genesis-workflows`** | The shared GitLab repo (library) holding all workflow packages + registries + authoring steering. |
| **`kiro-agent-sdk`** | The Python SDK that drives Kiro's agent over ACP; the agent-node adapter (already built). |
| **`genesis-core`** | Shared package (node factories, `RunWorkspace`, base state) depended on by both the platform and every workflow. |
| **Node** | A step in a workflow graph. Kinds: program, agent, cli, validator, gate, subgraph. |
| **Program node** | Deterministic Python step (transform/parse/assemble). Default choice. |
| **Agent node** | A narrow Kiro turn via ACP (`kiro_node`) with per-node MCP injection; writes output to a blackboard doc. |
| **CLI node** | Wraps an external CLI (e.g. `erd-gen`) with typed argv + output parsing. |
| **Validator (node)** | Deterministic program check of a prior artifact; routes pass/fail. Makes the *program* decide "good enough." |
| **HITL gate** | A pause node (`interrupt()`) for human approval / feedback / escalation. |
| **Subgraph node** | Embeds another workflow's compiled graph (composition). |
| **Reliability trio** | The mandatory pattern: agent node → validator → retry/escalation. Hard requirement, CI-enforced. |
| **ACP** | Agent Client Protocol — JSON-RPC over stdio that `kiro-cli acp` speaks; how Genesis drives Kiro. |
| **MCP** | Model Context Protocol — external tool servers (Atlas, Jarvis, LCP, data-generator, Jira) injected per node. |
| **MCP registry** | `mcp-registry.json` — shared launch configs + secret keys for MCP servers. |
| **CLI registry** | `cli-registry.json` — shared external CLI definitions. |
| **Per-node MCP injection** | Opening an ACP session with only the MCP server(s) a node needs (ADR-004/005). |
| **Blackboard** | The per-run artifacts folder (`<artifacts root>/<workflow_id>/<run_id>/`, `RunWorkspace`) holding bulk data + cross-step handoff docs. |
| **Artifacts root** | The dedicated, user-configurable directory for bulk run data (default `~/Genesis/runs/`, `GENESIS_ARTIFACTS_DIR`), separate from `~/.genesis/` state. |
| **Retention** | Configurable pruning of **terminal** runs' artifacts (keep-last-N / delete-after-X-days; intermediate vs final); never touches live/paused runs. |
| **`PlatformState`** | The small, serializable, editable LangGraph state (metadata, artifact pointers, decisions, status). |
| **Artifact** | A file in the blackboard, referenced from `state.artifacts` by a logical name. |
| **Checkpointer** | LangGraph SQLite saver; per-superstep snapshots enabling resume/edit/fork. |
| **Run / thread** | One execution of a workflow; `run_id == thread_id`. |
| **Catalog** | The user-facing projected list of installable workflows (from `registry.json`). |
| **Bundle** | A curated set of workflows for a role (e.g., "Tester set") — `bundles.json`. |
| **Lockfile** | `installed.lock.json` — installed workflows + pinned refs on a machine. |
| **SecretProvider** | Local secret store abstraction (`scope/VAR`); plaintext v1 (`0600`), keychain-ready. |
| **Environment registry** | `environments.json` — credential-free Appian env labels (url/api_endpoint). |
| **Role** | A persona tag (developer/tester/product-owner/ux-designer) used to filter the catalog. |
| **Reliability lint** | The CI check (`check_reliability`) enforcing the trio on every agent node. |
| **HITL** | Human-in-the-loop: (1) approval gates, (2) pause/resume anywhere, (3) mid-run state injection. |
| **`auto_approve`** | `META` default (`true`): validated steps auto-advance; the run pauses only at the three sanctioned pause classes. Prevents approver fatigue. |
| **Sanctioned pause classes** | The only places a run auto-pauses: (a) author approval gates, (b) escalations, (c) pre-mutation. |
| **Pre-mutation gate** | A required `hitl_gate(kind="pre_mutation")` before any write/deploy/data MCP node. |
| **Fork / time travel** | Creating a new run from a past checkpoint (with edits), leaving the original intact. |
| **`Send`** | LangGraph dynamic map-reduce (fan-out per item), e.g. one agent call per table/app. |
| **LCP MCP** | The Appian design-object authoring MCP (create record types/interfaces/process models/sites) — the OD-1 unlock. |
| **doc-19** | solutions-copilot's `19-workflows-orchestration-deferred.md` — effectively Genesis's requirements. |
| **OD-1/2/3** | Open decisions: LCP authoring viability / ACP+API-key / ACP session pooling. |
| **M6** | The milestone: complete application + ERD workflow (Studio interim UI). |
