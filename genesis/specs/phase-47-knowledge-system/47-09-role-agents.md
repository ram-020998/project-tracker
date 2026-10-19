# 47-09 — Role agents, skills and hooks

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Agent: `kiro_default` with the
> `procedures/*` and `CORE.md` built in 47-07. Review: `genesis-migration-reviewer`.

## Agents (sources in `genesis/agents/`, installed into `~/.kiro/agents` by `install.sh`)
| Agent | Always loaded | On demand | Writes |
|---|---|---|---|
| `genesis-spec` | `CORE.md` + `spec-authoring` | area skills it pulls in as the feature unfolds | `phases/<n>/` specs (each sub-spec with a context manifest) |
| `genesis-build` | `CORE.md` + `build-loop` | **exactly** the sub-spec's manifest, via `gk context` as step 1 | code repos; `phases/<n>/handoffs/` |
| `genesis-review` | `CORE.md` + `review` | every rule `gk rules --paths <diff>` returns, plus the manifest's areas | `phases/<n>/reviews/` |
| `genesis-release` | `CORE.md` + `release` + `fleet-and-live-acceptance` | `state/current.yaml` | code repos (versions, tags), `phases/<n>/handoffs/` |
| `genesis-docs` | `CORE.md` + `docs-upkeep` | the areas the phase touched | **the only writer of `knowledge/`**; `history/INDEX.md`; `state/` |

`genesis-docs` is called once a phase is complete and released. Its inputs: the phase's handoffs, the git log and
diffs since the previous release tags, the release tags and CI ids, the manifests. It integrates the new
knowledge into the right documents (never a dated journal entry), adds new ADR and lesson files, refreshes state,
adds the history row, re-runs `gk validate/build/copycheck` and the examination of the touched areas with the new
lessons as questions, then commits and pushes project-tracker.

## Work
1. Configs + prompts for the five agents (resources: `file://…/_build/CORE.md`, `skill://…/_build/**/SKILL.md`;
   write limits per the table; the deny list; launched without trust-all, umbrella §8).
2. **Spike, recorded in the handoff:** does `agentSpawn` hook output reach the model's context; does a
   `preToolUse` hook on `write` receive the target path (if yes, add a hook that prints `gk rules --paths
   <target>`); how much the inherited defaults add (`/context show` from the launch directory — e.g. the home
   `AGENTS.md`); decide the launch directory. Do **not** change the global
   `chat.disableInheritingDefaultResources` setting without the user (it affects every other agent).
3. `agentSpawn` hook: `gk state show` (versions) + the repos' HEADs.
4. Measure each agent's start-up context with `/context` → must meet S1 (≤ 60K tokens with a typical manifest).

## Definition of Done
Agents validate and pass guardrail smoke tests · spike results recorded · start-up context measured per agent ·
`install.sh` idempotent.

## Verification (reviewer — umbrella §6 plus)
Re-run the smoke tests; check every prompt against its procedure (no mandatory step missing); check the write
limits match the table; check `genesis-docs` is the only agent that can write `knowledge/`.
