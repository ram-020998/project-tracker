---
name: genesis-spec-authoring
description: Use when authoring a Genesis phase spec set — the umbrella + sub-specs in the house format, each sub-spec's context manifest, the mandatory sub-spec set, the Q&A protocol and the status vocabulary. For the genesis-spec (and genesis-docs) agent.
---

# Writing a Genesis spec set

Genesis specs are an **umbrella** (`specs/phase-NN-<slug>.md`) plus **sub-specs**
(`specs/phase-NN-<slug>/NN-MM-<slug>.md`). Move text, don't rewrite the bible. One home per fact (47-08).

Exemplar to copy the shape from (read in ranges, do not paste whole):
`{{TRACKER}}/specs/phase-46-spec-change-requests.md` and its sub-specs
`{{TRACKER}}/specs/phase-46-spec-change-requests/46-01-findings.md` … `46-07-web-experience.md`.
Layout + manifest rules: `{{TRACKER}}/specs/phase-47-agent-context-system/47-02-layout-and-metadata.md` §5.

## Mandatory sub-spec set (every phase)
1. **NN-01 findings** — measurements, research, options, and **every decision** (one row each, with the reason).
2. **API** sub-spec — or record **"N/A"** in the umbrella's sub-phase ledger when the phase has no HTTP API.
3. **review & acceptance** — code review + hardening + live acceptance. For table/list UI, budget a real-browser
   width probe (several widths, both themes) in the acceptance table — jsdom can't see layout (L-090).
4. **release & onboarding** — release steps + the docs write-back.
5. **feature sub-specs** — one per cohesive feature.

## Umbrella skeleton
Status banner · Why this phase exists · Goal · Decisions (locked, with the user) · Design overview ·
Session plan · Sub-phase ledger (table: sub-phase · repo · content) · Release plan · Scope (In/Out/Deferred) ·
Defaults · Risks · ADR summaries. Keep history out; link to `progress/`.

## Every sub-spec (phase ≥ 48) ends with a context manifest

A `## Context manifest` heading followed by a fenced ` ```toml ` block with these keys (all optional arrays of strings):

- `areas` — area names from `context/areas.toml` (`{{GENESIS_HOME}}/bin/genesis-ctx area <name>`).
- `adrs` — the ADR ids this task must honour **in full**. **MANDATORY, not just "extras":** run
  `{{GENESIS_HOME}}/bin/genesis-ctx area <a>` for every area above and copy each applicable ADR id here.
  The pack renders only these (plus path-glob hits and their amendment chains) as **full text**; an ADR
  that reaches the pack only through its area gets a one-line *Also applies* pointer, not its decision log.
- `lessons` — same rule: list every lesson id the task must honour in full (from `genesis-ctx area <a>`).
- `docs` — docs to read next (`"tracker:specs/.../NN-02-foo.md"`, `"reference/foo.md"`).
- `code` — path globs the task touches (drive path→area routing; e.g. `"genesis/genesis/foo/**"`). A bare
  directory routes as `<dir>/**`; prefer the explicit glob.
- `upstream` — sub-spec ids whose **As-built** must be read first (e.g. `"NN-02"`).

`{{GENESIS_HOME}}/bin/genesis-ctx pack <id>` = manifest ∪ area defaults ∪ path-derived areas ∪ amendment closure.
**Full text** is reserved for the manifest's `adrs`/`lessons`, path-glob hits and their chains; everything an area
adds is a one-line *Also applies* pointer you load on demand (`genesis-ctx adr|lesson <id>`). So list the ids you
need in full explicitly — area membership alone gives only the pointer. Recall (every cited rule ∈ full ∪ listed)
stays 100 %; two routes must both miss before a rule is lost, and the review `check` on the diff is the third.
Keep packs under budget by naming tight `areas`/`adrs`, not whole catalogs.

## Q&A protocol
Ask ONE question at a time. Record each answer immediately in findings §Decisions (D1, D2 …) with the reason.
Never batch questions. Research externally (web) when a library/API/standard is involved; cite it.

## Status vocabulary (umbrella Status line)
`SPEC-DRAFTED` → `BUILT` (per sub-spec) → `SHIPPED`. Sub-spec status uses the same words in its own banner.

## Finish
`{{GENESIS_HOME}}/bin/genesis-ctx lint --specs-only` green (unknown area/ADR/lesson/upstream or a missing manifest fails it).
Update the README phase row to the new status. Commit specs locally in project-tracker; push only on the user's go-ahead.
