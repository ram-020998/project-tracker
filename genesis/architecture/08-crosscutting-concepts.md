# 8. Cross-cutting concepts

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · arc42 section 8

A cross-cutting concept is a rule or pattern that many modules follow. Each section below states the rule,
says why it exists, and points to the modules that implement it. When you change any module, check the
sections that apply to it.

## 8.1 Reliability of agent output

**Rule.** No agent output is used until program code has checked it.

- Every agent step in a workflow is followed by a validator, a retry loop and an escalation gate: the
  *reliability trio* (ADR-011). A lint (`genesis/lint/reliability.py`) refuses a workflow without it.
- Workflows that assemble a large artifact add a *healing* tier: a grounded verify step, then a patch of only
  the flagged items, or one guided restart, then a person (ADR-067). The budget is bounded by `META.healing`.
- Agents write to files the program pre-creates and then validates. They never return bulk content through
  chat (L-021).
- A large deliverable is split into parts the program assembles, because one long agent turn truncates (L-064).
  Parts that must agree with each other stay in one turn (L-076).

Where: [core-engine.md](modules/core-engine.md), [workflow-library.md](modules/workflow-library.md).

## 8.2 State, the blackboard and files

**Rule.** LangGraph state holds pointers and small decisions. Bulk lives in files. The database stores paths and
content hashes, not documents.

| Kind of data | Home |
|---|---|
| A run's inputs, decisions, status, retry counts, telemetry | LangGraph state (checkpointed in `genesis.db`) |
| A run's bulk files (exports, drafts, reports, prompts, tool results) | The run's blackboard `~/Genesis/runs/<workflow>/<run>/` |
| Authoritative stage, story-stage and document content | Files under `~/.genesis/feature-stage-artifacts/`, `story-stage-artifacts/`, `kb-documents/`; rows point at them |
| Test code | A git repository per application under `~/.genesis/testing/apps/` (ADR-081) |
| Appian SAIL code | Nowhere. It is read live through the Dev MCP when needed (ADR-037) |

Why: checkpoints stay small and editable by a person; agents get context as files, not as chat (L-042); content
can be replaced without migrations.

## 8.3 Durability and consistency

Genesis assumes processes die at any moment. These rules keep data correct anyway.

1. **One durable store.** All durable data is in SQLite (WAL mode, 30 s busy timeout). The run event log
   (`run_events`) is the source of truth for a run's history; status columns are copies (ADR-024, ADR-030).
2. **Schema by migration only.** Stores never create tables. Migrations are forward-only and numbered. A table
   rebuild turns foreign keys off outside the transaction (L-102).
3. **Compare-and-set for stop states.** A terminal status is written with one `UPDATE … WHERE status NOT IN
   (terminal)`; only the winner announces it (L-108). Domain records use `row_version` for optimistic locking;
   a stale write answers 409.
4. **Take the write lock first.** A transaction that validates and then writes starts with the write
   (`BEGIN IMMEDIATE` or the compare-and-set), so two writers cannot both pass validation (L-091).
5. **Store, then announce.** A terminal state is stored before the event that describes it, so an observer that
   re-reads the record sees it (L-093).
6. **Level-triggered recovery.** Every bridge from a finished run to a domain record reacts to the live event and
   also reconciles at startup and on read, and fails loudly (L-058).
7. **Bind to the current run.** A finalizer acts only for the run currently bound to its record, so an old run
   cannot overwrite a re-run (L-061).
8. **Derived rows go with their source.** An index table without a foreign key is cleaned in the same
   transaction as its source, and readers join to the source (L-103).
9. **Crash-safe files.** JSON configuration files are written atomically (temp file, then `os.replace`) under a
   per-path lock (L-019).

Where: [data-and-migrations.md](modules/data-and-migrations.md), [runs-and-workers.md](modules/runs-and-workers.md).

## 8.4 Events and streaming

- Run events use a fixed set of canonical kinds: `run.started`, `node.completed`, `agent.prompt`,
  `agent.message`, `agent.thought`, `agent.tool_call`, `agent.tool_update`, `agent.result`, `validator.result`,
  `retry.scheduled`, `telemetry`, `gate.awaiting`, `gate.resolved`, `run.final`, `error`, plus `custom`. There is
  no `node.started` or `node.failed` (L-005).
- The browser follows a run through Server-Sent Events: replay from the durable log after a sequence number,
  then live events, de-duplicated by `seq`. The client closes the stream on a terminal `run.final` (L-003).
  Frames may be separated by CRLF (L-018).
- Node status in the UI comes from server-side folds of the full log (`/steps`, `/transitions`), never from a
  capped client fetch or a full refold per tick (L-060, L-066).
- The web types and golden fixtures mirror every contract shape, so a drift fails a test (L-011).

Where: [runs-and-workers.md](modules/runs-and-workers.md), [web-app.md](modules/web-app.md).

## 8.5 Human control

| Control | Where it applies |
|---|---|
| Designed gates (`approval`, `escalation`, `pre_mutation`, `review`) | Any workflow; `pre_mutation` before writes unless a confirm is the approval (ADR-021) |
| Pause, resume, cancel | Any run |
| State edit and fork | Any run, limited to editable keys (ADR-009, ADR-025) |
| Confirm dialogs that start workflows | Stage starts; the Design, Implementation and Verification lanes (ADR-062, ADR-068, ADR-084) |
| Confirm cards for chat mutations | Copilot mode (ADR-033) |
| Irreversible actions behind an explicit step | Finalize Stories, Finalize Test Design (ADR-060, ADR-078) |
| Program applies what chat drafts | Spec change requests (ADR-076) |

A gate's prompt is built from the run's state, so each option does what it says (L-106).

## 8.6 Security and trust

Genesis is a local, single-user tool. The model below is what it defends and what it does not.

| Threat or boundary | Defence | Limit in v0.81.0 |
|---|---|---|
| Network access to the app | Binds to loopback only; a non-loopback bind needs `--i-understand-no-auth` (ADR-026) | No authentication: any local process or web page can reach `127.0.0.1:8760`; a body-less cross-site POST is not blocked |
| Untrusted HTML in Playwright reports | Served only from a second loopback origin (port + 100) with no `/api` (ADR-085) | Reports on that origin can read each other |
| Untrusted HTML in the story verification report | Served as a script-free page with a restrictive Content-Security-Policy; links to report files point at the reports origin | — |
| Chat agent doing harm | Fixed read-only trust list in `@server/tool` form, `auto_deny` for everything else, writes only into the session folder, mutating copilot tools always ask (ADR-031, ADR-033, ADR-034) | — |
| Workflow agent doing harm | Per-step MCP servers, a trust set capped by server allowlists (ADR-029); credentials never in prompts | Permission requests are auto-approved, Kiro's shell is available, the user's global Kiro MCP servers are loaded, and the shell inherits the environment (ADR-083 accepted risks, until agent isolation ships) |
| Writes to a customer application | Only the Implementation lane, one blanket approval, rollback document first, no delete tools (ADR-068) | — |
| Test traffic | QA only, as the application's test users, through the UI only (ADR-082) | — |
| Secrets | Stored by key name in `~/.genesis/secrets.json` (mode 0600); never in state, `environments.json` or logs; test-user passwords reach only the sign-in and Playwright subprocesses; reports are scrubbed in every escaped form (L-105) | The store is a plaintext file protected by file permissions |
| Supply chain of tools | Internal tools run as `npx --no-install <bin>` from their own install (L-101); managed MCP servers and CLIs are versioned local installs (ADR-038, ADR-040) | — |
| Agent output leaking a secret | Any value that reached agent output counts as leaked and is rotated; agents never call CI-variable APIs (L-100) | — |

Where: [configuration-and-secrets.md](modules/configuration-and-secrets.md), [chat-and-skills.md](modules/chat-and-skills.md),
[testing.md](modules/testing.md), [api.md](modules/api.md).

## 8.7 One authority for status changes

Every status change of a spec, stage, story or test item goes through `LifecycleService.transition` with a
table of legal moves and guards; each successful move is written to `lifecycle_transitions` (ADR-050). Two
deliberate exceptions exist: Workbench drags move cards freely (ADR-061), and some stage-start routes set
`in-progress` directly. Both are documented in their modules.

Where: [features-and-stages.md](modules/features-and-stages.md#51-the-lifecycle-service).

## 8.8 Identifiers

| Id | Format | Allocated by |
|---|---|---|
| Run | `r-<12 hex>` | `RunManager` |
| Chat session | `c-<12 hex>` | `ChatManager` |
| Story key | `GNS_<6 digits>` | `kb_sequences` inside the finalize or create transaction (ADR-072) |
| Test records | `TC-`, `TS-`, `ACT-`, `DS-`, `TE-` with 6 digits | `kb_sequences` |
| Spec clause | `c-<8 hex>` in a `data-cid` attribute | Program code only (ADR-075) |
| Change request | `CR-<nn>` per spec | `SpecChangeStore` |
| Shared record | `sync_uuid` | Set at creation, used by the Hub (ADR-063) |
| Appian object | `(app_uuid, object_uuid)` | Appian; stored only when the KB confirms it (L-095) |

## 8.9 Configuration

- All machine state is under `~/.genesis/` (`GENESIS_STATE_DIR`); run folders are under `~/Genesis/runs/`
  (`GENESIS_ARTIFACTS_DIR`). The full layout is in
  [configuration-and-secrets.md](modules/configuration-and-secrets.md#51-the-state-folder-and-how-settings-are-read).
- Environment variables are read once per process by `Settings.load()`. Anything a user changes in Settings
  lives in a JSON file or the database, not in `Settings`.
- Workflow behaviour is configured in `META` (retries, healing, recursion limit, auto-approve, editable keys).

## 8.10 Versioning and compatibility

| Key | Meaning | Changes when |
|---|---|---|
| The repo tag `vX.Y.Z` | One shared version for the app and its three libraries (ADR-080) | Every release |
| `CORE_MAJOR` | Compatibility between the platform and the workflow library; a mismatch refuses to load (ADR-019) | A breaking change to genesis-core's public API |
| `KB_FORMAT_VERSION` | The parser's output format; a lower recorded value forces a full KB sync | A parse-output change that needs a full re-sync |
| Database `schema_migrations` version | Per database (`genesis.db`, `memory.db`) | A new migration |
| Lockfile `libraryRef` and per-workflow refs | What is installed | An install or update |

Before unifying versions, behaviour keyed on a version string must move to its own constant (L-099). A release
must move every pin that depends on the tag (L-057) and include every changed file (L-056).

## 8.11 Error handling

- Fail fast before spending: unresolved MCP variables, missing skills and an uninstalled workflow stop a run
  before Kiro starts, with a message that says what to install or set (L-033).
- API errors use FastAPI's `{"detail": …}` body. Conflicts answer 409 with a structured detail (for example
  `illegal_transition`, `stale_write`), refusals with a list of `problems`. See [api.md](modules/api.md).
- A generic failure must not replace a specific one (L-008). Background jobs reach a terminal state on every
  error path (L-107).
- Observability must never break the work: event emission and observers are wrapped so their failures are
  logged and ignored.

## 8.12 Processes the app starts

| Process | Started by | Stopped by |
|---|---|---|
| Run worker | `RunManager` | Exit at the end of the operation; SIGTERM on pause or cancel |
| `kiro-cli acp` | The SDK, per agent step or chat session | `close()` (SIGTERM, then SIGKILL) |
| MCP servers | Kiro | Kiro, with the session |
| Browser sessions, recorders, Playwright | Test program steps through `apwt` | Reaped from `<run>/.pids` when the run ends, pauses or is cancelled; matched by full command line (L-104) |
| Background setup jobs | `TestingJobs` | Their own end; stale children reaped at startup |

## 8.13 Testing strategy

- Backend: `pytest` with fake agents (`set_collect_impl`, `set_agent_provider`) and fake ACP engines, so no
  test needs Kiro. A bug fix adds a regression test; a stub that hid a bug is fixed to mirror reality (L-083).
- Web: Vitest, jest-axe for interactive UI, golden fixtures for contracts, and a real-browser geometry probe for
  layout questions (L-090).
- Workflows: each workflow folder has its own tests; the library's publish gates check the whole library.
- A unit counts as proven only by what ran: its own step, at the recorded commit, over its whole dependency
  closure (L-110). Code review does not replace live acceptance (L-111). Long local work gets a CI run before
  the release commit (L-112).

Gate commands per module are in each module document.
