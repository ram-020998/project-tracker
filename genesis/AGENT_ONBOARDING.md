# Genesis — Agent Onboarding

> **Since Phase 47 (2026-10-20) there is no "read the bible".** Genesis work is done by five role agents that start with
> a small always-loaded core and pull exactly the rules a task needs through `genesis-ctx`. The old bible index is
> archived verbatim in [`archive/agent-onboarding-pre-47.md`](archive/agent-onboarding-pre-47.md); every ADR, lesson and
> code-map entry is still here, now loaded per task (ADR-077).

## For the human

Use the agents from your root workspace (never from inside project-tracker), on the V3 engine:

```bash
cd ~/repo-gitlab/ramaswamy.u
kiro-cli --v3 chat --agent genesis-spec      # spec a phase
kiro-cli --v3 chat --agent genesis-dev       # implement one sub-spec
kiro-cli --v3 chat --agent genesis-review    # independent review + live acceptance
kiro-cli --v3 chat --agent genesis-release   # version, tag, push, CI (asks first)
kiro-cli --v3 chat --agent genesis-docs      # documentation write-back after a phase
```

Step-by-step usage, prompts and troubleshooting: [`agent-system/OPERATOR_GUIDE.md`](agent-system/OPERATOR_GUIDE.md).
Install / update the agents: `agent-system/install.sh` · `agent-system/update.sh` (sources live in `agent-system/`).
Never launch Genesis agents with `--trust-all-tools`.

## For an agent

**If you are a `genesis-*` agent:** your context is already loaded — follow your role prompt and the retrieval protocol
in `context/L0-core.md` §3. Do not read this folder's bulk files whole.

**If you are any other agent** (no Genesis profile), load the same core yourself, in this order, then use the tool:

1. `context/L0-core.md` — what Genesis is, where things are, the retrieval protocol, key implementation contracts
2. `bible/02-architecture.md` — the mental model
3. `bible/07-working-on-tasks-and-agreements.md` — the work loop and working agreements
4. `context/_generated/adr-digest.md` — one line for **every** ADR (non-negotiable)
5. `context/_generated/lesson-digest.md` — one line for **every** hard-won lesson (do-not-regress)
6. `context/_generated/area-catalog.md` — the areas
7. `context/state/current.md` — current versions and state

Then, for the task: `agent-system/tools/genesis-ctx pack <sub-spec>` (or `pack --areas <a,b>`), and
`genesis-ctx adr <id> <id> …` / `lesson <id>` for full text (one call, multiple ids). History:
`genesis-ctx search <term> --archive`. Live repo status: `genesis-ctx status --brief`.

## Where knowledge lives (one home per fact — `agent-system/skills/genesis-doc-writeback`)

| Kind | Home |
|---|---|
| ADRs (full text) | `reference/decision-log.md` (+ `bible/04` digest bullets) · tags in `context/tags/adr.toml` |
| Hard-won lessons | `bible/06-hard-won-lessons.md` (`<!-- L-NNN -->` markers) · tags in `context/tags/lesson.toml` |
| Code map | `bible/03-codebase-map.md` · tags in `context/tags/codemap.toml` |
| Areas | `context/areas.toml` |
| Current state | `context/state/current.md` (overwritten each phase) |
| Phase plans / as-built | `specs/` · `progress/` · one line per phase in `context/changelog.md` |
| Backlog | `specs/backlog/` (index in `bible/08`) |
| History | `archive/` (verbatim; search, don't read whole) |
