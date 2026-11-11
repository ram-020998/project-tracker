# 5. Solution strategy

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · arc42 section 4

This page lists the key ideas the whole architecture rests on. Each one answers a quality goal from
[section 1.3](01-introduction-and-goals.md#13-quality-goals). If you remember only one page, remember this one:
most rules in the code follow from these ideas.

## 5.1 The ideas at a glance

| # | Idea | Serves goal | ADRs |
|---|---|---|---|
| 1 | Code owns the control flow; agents do narrow turns | Trustworthy output | ADR-001, ADR-002 |
| 2 | Every agent output is checked by code, retried, then escalated | Trustworthy output | ADR-011, ADR-067 |
| 3 | Small state, bulk on the blackboard | Durability, human control | ADR-010, ADR-018, ADR-022 |
| 4 | Workflows run in disposable worker processes | Durability, safety | ADR-012 |
| 5 | Everything durable is in SQLite; the event log is the run's history | Durability, observability | ADR-024, ADR-030 |
| 6 | Three ways for a person to step in | Human control | ADR-009, ADR-021, ADR-025 |
| 7 | Each agent gets only the tools it needs (fully for chat; partly for workflow agents until Phase 52) | Safety | ADR-004, ADR-020, ADR-029, ADR-083 |
| 8 | Chat observes; program code changes things | Safety, human control | ADR-031, ADR-033, ADR-034, ADR-076 |
| 9 | Workflows are installable packages from a shared library | Simple authoring | ADR-006, ADR-014, ADR-019 |
| 10 | Program-owned bridges turn finished runs into domain records | Durability, trustworthy output | ADR-050, L-058, L-093 |
| 11 | Real metered credits, honest provenance | Observability | ADR-032 |
| 12 | Local-first, single user, opt-in sharing | Local-first, safety | ADR-026, ADR-063 |
| 13 | One repo, one version, one install command | Simple operation | ADR-046, ADR-080 |

## 5.2 The ideas explained

### 1. Code owns the control flow; agents do narrow turns

A workflow is a **LangGraph** graph. The graph's edges, written in Python, decide which step runs next. An agent
step is one Kiro conversation turn with one clear job, such as "write the analysis to this file". The agent
cannot choose the next step, call another workflow or loop on its own.

*Why:* the tool Genesis replaced let an AI model plan and sequence the work, and its runs drifted, looped and
were hard to repeat. A fixed graph makes runs predictable, testable and resumable.

### 2. Every agent output is checked by code, retried, then escalated

Every agent step must be followed by a **validator**: a program function that reads the step's output file and
decides whether it is good enough. If the check fails, the step runs again with the failure message added to its
prompt. After a set number of retries, the run stops at an **escalation gate** and a person decides. This
"reliability trio" (validator + retry + escalation) is required for every agent step. A lint
(`genesis/lint/reliability.py`) refuses to publish a workflow without it.

A second tier, **healing**, works on a whole assembled artifact. A critic agent checks it against its sources and
lists item-level fixes. A healer agent either patches only the flagged items, or restarts the workflow once with
guidance. The ladder is bounded (by default one patch and one restart), then a person decides. This avoids
re-running a whole expensive workflow for one wrong paragraph (L-075).

### 3. Small state, bulk on the blackboard

LangGraph state holds only small things: inputs, pointers to files, decisions, status, retry counters, telemetry.
Anything big (an exported application, a generated document, a tool result) is a file in the run's folder, the
**blackboard**, and state holds its path.

*Why:* state is checkpointed after every step and shown to people for editing. Keeping it small keeps
checkpoints cheap, keeps state editable by a person, and keeps bulk text out of agent prompts. A large tool result
is saved by reference, so its bytes never pass through the model (L-021).

### 4. Workflows run in disposable worker processes

The app process never imports a workflow's Python. Each run operation starts a fresh worker process. The worker
loads `graph.py` from the installed library, runs until the graph stops (done, a gate, or an error), and exits.
Because every step is checkpointed, the worker holds nothing that cannot be rebuilt. **Pause** kills the worker;
**resume** starts a fresh one from the checkpoint.

*Why:* a buggy or hanging workflow cannot crash or block the app. Pause works at any moment, even in the middle of
a long agent turn.

### 5. Everything durable is in SQLite; the event log is the run's history

Runs, checkpoints, the full agent conversation, chat sessions and all domain data live in one SQLite file in WAL
mode. A forward-only migration runner owns the schema. For runs, the append-only `run_events` table is the source
of truth for what happened. The in-memory event bus only pushes new events to open browser tabs.

*Why:* a reload or a server restart must show the same run history. Status fields are a convenience copy;
when they disagree with the log, code trusts the log (`RunManager.reconcile_status`).

### 6. Three ways for a person to step in

1. **Designed gates.** A workflow can stop at a gate of kind `approval`, `escalation`, `pre_mutation` or
   `review`. The person answers approve, reject, or free-text feedback.
2. **Pause and resume** anywhere, by killing and restarting the worker.
3. **State editing and fork.** A person can edit the editable keys of a run's state, or fork the run: a new run
   starts from a past checkpoint with the edits, and the original run is left untouched.

Workflows run without stopping by default (`META.auto_approve = true`), and must stop at a `pre_mutation` gate
before any write to Appian, unless a confirm dialog in the UI is the approval (ADR-021, ADR-068).

### 7. Each agent gets only the tools it needs

Kiro is never given a global tool configuration by Genesis. Each agent step lists the MCP servers it needs; the
platform resolves their launch commands and secrets and passes them to that one Kiro session. If the step lists
tools, trust is that list capped by each server's allowlist. Chat trusts only a fixed list of read tools, written
in Kiro's `@server/tool` form, and denies everything else (L-017).

In v0.81.0 this idea holds fully for chat but only partly for workflow agents. Their permission requests are
auto-approved, and Kiro adds the servers from the user's own global configuration. ADR-083 accepts this risk
until the agent isolation work (Phase 52) puts every agent turn in a sandbox.

### 8. Chat observes; program code changes things

Chat can read runs, the knowledge base, memory and documents. In copilot mode it can start runs, answer gates and
cancel runs, and each of those calls shows the person a confirm card first. Chat may write files only into its
per-session output folder. Larger changes (finalising a stage, applying a spec change request, moving a story)
are done by program code after the person confirms. Chat may draft a change; program code applies it.

### 9. Workflows are installable packages from a shared library

A workflow is a folder with a `workflow.yaml` (metadata, inputs, topology for the UI) and a `graph.py` (a static
`META` dict and a `build(ctx)` function). The library repo lists them in a catalog. A user installs a selection,
pinned by git ref in a lockfile. The loader refuses a library built for a different `CORE_MAJOR` of genesis-core.
A scaffolder (`genesis create-workflow`) creates a folder with the reliability trio already wired.

### 10. Program-owned bridges turn finished runs into domain records

Many workflows produce something a domain record needs: a stage artifact, a story design, test results. A
**finalizer** in the app process watches for the run's terminal event and then writes the domain record. Each
finalizer also runs at startup and when a page reads the record, so a run that ended while the app was down is
still finalised (level-triggered recovery, L-058). The run's terminal status is stored *before* its final event
is announced, so a finalizer that re-reads the record sees it finished (L-093).

Every status change of a domain object (spec, stage, story, test item) goes through one `LifecycleService` that
knows the allowed transitions (ADR-050).

### 11. Real metered credits, honest provenance

Kiro reports the credits each turn used. The SDK reads that report and passes it up. Every credit figure carries
a provenance: `metered`, `partial` or `unavailable`. When Kiro did not report a number, Genesis shows that it is
missing. There is no pricing engine and no estimate.

### 12. Local-first, single user, opt-in sharing

Genesis runs on the user's machine with the user's credentials and binds only to loopback. Sharing with
teammates is a separate, opt-in layer: when both the environment switch and the Settings switch are on, a defined
subset of data is published to and pulled from the Genesis Hub. Everything works without it.

### 13. One repo, one version, one install command

The app and its three libraries live in one repo and share one version, which is the git tag. No internal package
lists another as a dependency; `scripts/install-packages.sh` installs all four from the checkout. The app updates
itself by checking out the newest tag. The core's compatibility key (`CORE_MAJOR`) is separate from the version
and changes only on a breaking change.

## 5.3 How the ideas meet in one run

A short walk through one workflow run shows most of the ideas working together:

1. The user clicks Run. The app validates the inputs against the workflow's schema, creates the run record and
   logs `run.started` (idea 5).
2. The app starts a worker (idea 4). The worker loads `graph.py` and builds a context with the run's blackboard,
   registries and secrets.
3. A program step writes a file to the blackboard and puts its path in state (idea 3).
4. An agent step starts `kiro-cli acp` with only its MCP servers (idea 7). The agent writes its output to a file;
   every streamed message and its metered credits become events (ideas 5, 11).
5. The validator reads the file. It fails once, so the step runs again with the reason; the second attempt passes
   (idea 2).
6. A `pre_mutation` gate stops the run. The worker exits. The user reads the artifact and approves (idea 6).
7. A fresh worker resumes from the checkpoint, finishes, and the run ends `done`.
8. A finalizer sees the terminal event and copies the artifact into the feature's stage record, through the
   lifecycle service (idea 10).
