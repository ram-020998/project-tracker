# 01 — Overview & Branching / Isolation Strategy

## What `appian-dev` is

`appian-dev` (also called **DevMCP Local**) is Appian's near-term answer to **branching and
isolation** for agentic development. It is the productization of a CLI originally built by
Matt Hilliard, now owned by a small team (Kelsey Ross, Justin Ingram, Matt Hilliard) under
Solutions Acceleration.

The core idea: instead of agents editing a shared Appian dev environment directly (the
current "Dev MCP" model), `appian-dev` **checks a copy of an application out of the
environment onto the local filesystem as YAML files**, lets AI agents (Claude Code, Kiro,
Codex, …) develop against that local copy in isolation, and **merges** the result back
through the same validated plugin endpoints. A human reviews before the merge.

```
User → Agent (Claude/Kiro/Codex) → appian-dev CLI + SAIL CLI
                                      → local MCP server (Go)
                                      → local design objects (YAML on filesystem)
                                      → DevMCP plugin on the Appian Dev environment
```

## The problem it solves

- Multiple agents under one signed-in user all mutate the same shared Appian dev server.
- There is no isolation, weak conflict handling, and weak rollback.
- Forcing agents to work within human-centric collaboration guardrails undermines their
  speed/scale advantage.
- Prior attempts with plain Git failed because Git cannot *verify* Appian-specific validity
  or give a human a runtime that mirrors a full Appian environment.

## Why not just Git? (the verification argument)

`appian-dev` positions itself as superior to Git for this use case on two kinds of
verification:

1. **Agent-side:** the agent can validate changes against Appian-specific functionality
   (the expression language, object shapes) to produce a *valid* design object — locally,
   without a round trip.
2. **Human-side:** the reviewer gets *visual runtime confirmation* — a live, interactive
   Appian page rendered locally that mirrors a full environment.

## Isolation options that were considered

| Option | Pros | Cons |
|---|---|---|
| **Client-side isolation** (teach design objects to branch) | aligns with today's dev lifecycle | splitting objects across 6 back-ends is complex; runtime isolation on one env is hard |
| **Server-side isolation** (a separate Appian env per branch) | perfect design + runtime isolation, full parity | doesn't scale to per-dev/per-agent branches; costly support; unplanned infra |

Neither scaled to agentic speed, so `appian-dev` (local, client-side, file-based) was
adopted as the "ship it now" solution.

## Target persona

"Bleeding edge": has third-party agent licenses, technically savvy, large team, shared
codebase. Examples: Appian solutions engineers, FDA, the GAM solution team.

Explicitly **out of scope (for now):** Composer integration, customers without AI licenses,
human-centric development, collaborative/shared remote branches, solution upgrades, native
data management.

## Delivery phases (per the Oct 2026 strategy deck)

- **NOW — Harden what exists:** fix early-adopter bugs, integrate with platform concepts
  (deployment, releases, packages), integrate with Dev MCP, release via App-Market.
- **NEXT — Integrate with `/design`:** a "Create Branch" button, cloud branching, branch
  awareness across teammates.
- **FUTURE — Go beyond the platform:** conflict-resolution UIs, Appian-specific testing &
  linting ("make the why-not-Git answer clear").

## Key risks called out

- Local-only → limited branch awareness / collaboration / review today.
- Relies on customers holding their own AI license.
- No in-product (`/design`, Composer) entry point yet.
- Imperfect parity: RPA, AI objects, RDO objects, integrations not supported at launch (maybe never).
- **AE / appian-dev drift:** infrastructure is being replicated in a new repo, so new platform
  features must work in both → higher engineering maintenance cost.
- Predominantly AI-generated codebase; little-to-no human UIs.

## Relationship to this project

For our purposes, the important takeaway is architectural: **the data transport is a plain
REST API** (the LCP API plugin) that we can call directly. The rest of these docs focus on
that API and the export pipeline so we can build an independent client. See
[`02-repository-and-branch-topology.md`](02-repository-and-branch-topology.md) next.
