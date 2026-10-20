<!-- context/L0-core.md — the hand-curated always-loaded core (Phase 47-05; 47-05 §3). Keep ≤ 4K tokens.
     §1 is bible/00 §0 verbatim; §4 is moved verbatim from bible/04 (pointer left there). -->

# Genesis — L0 core (always loaded)

## 1. What Genesis is

Genesis is a **local, single-user web application** that lets a Solutions engineer discover, install,
run, and supervise **workflows**. A workflow is a **LangGraph** graph whose nodes are deterministic
**program** steps or narrow **agent** steps that drive **Kiro** via `kiro-agent-sdk` over ACP,
injecting only the MCP server(s) that step needs. LangGraph owns control flow + durable state; a
per-run artifacts folder (the **blackboard**) holds bulk data; workflows are pulled from the shared
`genesis-workflows` GitLab repo via selective install + a lockfile. Every agent step is wrapped by a
program **validator + retry/escalation** (hard requirement). Genesis replaces the retired
solutions-copilot, which failed by using an LLM as the orchestrator. Backend = **FastAPI embedding
LangGraph as a library** + disposable **subprocess workers**; frontend = **React + TypeScript SPA**
served by the same backend. It runs on localhost with the user's own credentials. The destination is
"enterprise-grade polish" but **still local single-user** — multi-user/hosted is an explicitly separate
future track (ADR-026); **do not build auth/multi-tenancy unless asked.**

Since Phase 14 there is a **second first-class capability beside workflows: Skills** (ADR-034) — Kiro's
portable `SKILL.md` instruction packages for **standalone activities** (draft a document, apply a body of
knowledge like GAM) that the Kiro agent performs in **Chat**, with **no stages/orchestration**. A *Workflow*
= staged/orchestrated, owned by LangGraph; a *Skill* = a single standalone activity, owned by the Kiro agent.
Skills are filesystem-provisioned into a managed Kiro workspace (`~/.genesis/.kiro/skills/`) and invoked from
the Chat `/` palette (or auto-activated by description).

## 2. Where things are

- Code repos (root `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`): `genesis` (app: `genesis/genesis` backend + `genesis/web` SPA), `genesis-core`, `genesis-workflows`, `kiro-agent-sdk`, `genesis-appian-parser`.
- project-tracker (specs, progress, bible, context, archive): `/Users/ramaswamy.u/repo/project-tracker/genesis/`.
- Dev venv for all Python: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv`.
- Context tool: `genesis-ctx` (`project-tracker/genesis/agent-system/tools/genesis-ctx`).

## 3. Retrieval protocol

- The digests below list **every** ADR and lesson. Before acting on an area, get the full text:
  `genesis-ctx pack <sub-spec>` (or `--areas …`), or `genesis-ctx adr <id>` / `lesson <id>`.
- **Standard retrieval form — one direct call, many ids:** `<abs>/genesis-ctx adr ADR-021 ADR-032 ADR-035`
  (likewise `lesson L-056 L-057`), where `<abs>` is the absolute `bin/` path from your role prompt. Never wrap it in a
  loop, pipe, `;`/`&&`, `$(…)`, redirect or `VAR=` prefix: those fall outside the shell allow rule and are denied in a
  non-interactive session. Need only part of a long output? Use `pack --out <file>` plus a ranged read.
- Never open `reference/decision-log.md`, `bible/03`, `bible/04`, `bible/06` or `archive/**` whole; use
  `genesis-ctx` or ranged reads.
- For history ("when/why did we…"), use `genesis-ctx search <term> --archive`, then the `progress/` doc.
- If a digest line and a full text disagree, the full text wins; report the mismatch to the docs agent.
- For heavy exploration (many files), use a sub-agent and keep only its summary.

## 4. Key implementation contracts

**Key implementation contracts:**
- Node fns are `async fn(state, config: RunnableConfig)`. LangGraph injects `config` only when the param is annotated `RunnableConfig`; nodes read ctx via `ctx_from_config(config)`.
- `build(ctx) -> CompiledStateGraph` compiled with `ctx.checkpointer`. `META` is a static dict importable with NO side effects. `workflow.yaml` MUST mirror `META` (parity lint; UI-only keys like `graph:` are exempt via `YAML_ONLY_KEYS`).
- Workflow `graph.py` is loaded standalone (importlib on the file) — keep it self-contained (no sibling-package imports); put pure functions in `graph.py`.
- ACP MCP entries: `env` is a **LIST** of `{name,value}` (NOT a dict). See §7.

## 5. Non-negotiables in one breath

- ADRs are non-negotiable constraints — do not violate; flag + confirm if a task requires a deviation (ADR digest).
- Lessons are do-not-regress (lesson digest); re-read the full lesson before touching its area.
- Ask before destructive/irreversible actions (force push, history rewrite, deleting data, anything "prod").
- Never commit secrets; reference secrets by key name only; don't push beyond the normal Genesis release flow.
- Honest pushback; keep changes scoped; if stuck twice on the same error, find the root cause and change approach.

## 6. The agent system (who does what — ADR-077)

Five role agents, launched by the human from `~/repo-gitlab/ramaswamy.u` with `kiro-cli --v3 chat --agent genesis-<role>`
(never `--trust-all-tools`). Each hands off through files, not chat:

| Agent | Does | Writes / hands off |
|---|---|---|
| `genesis-spec` | Q&A → findings, umbrella, sub-specs | sub-specs with a `## Context manifest` (areas + explicit ADR/lesson ids + code paths) |
| `genesis-dev` | implements ONE sub-spec (commits locally; never pushes/tags) | code + the sub-spec's **As built** (commits, tests, review verdict, decisions, lesson candidates, code-map changes, Resume note); spawns `genesis-review` |
| `genesis-review` | independent review (`genesis-ctx check`) + live acceptance; never edits code | `specs/<phase>/reviews/*-review.md` with SHIP / NEEDS_CHANGES |
| `genesis-release` | versions, tags, pushes (always asks), CI, fleet | the release sub-spec's **As run** |
| `genesis-docs` | phase write-back; maintains the agent system | ADRs, lessons, code map, state, progress, changelog, README, tracker |

Command details: the `genesis-ctx` skill. Changing agents, skills or hooks: edit `agent-system/` in project-tracker,
then `agent-system/update.sh` (skill `genesis-agent-system`). The human's guide: `agent-system/OPERATOR_GUIDE.md`.
