# 47-05 — Tag review, L0 core, current-state snapshot

> **Status:** 🟡 SPEC-DRAFTED 2026-10-20. Repo: project-tracker. Parent: `specs/phase-47-agent-context-system.md`.
> Decisions D1, D7, D9. Input: `context/tags/*.proposed.toml` from 47-04 step 5. Session S4 (with the user).

## 1. Goal

Turn the script's tag proposals into reviewed tags, write the two small hand-curated files (`L0-core.md`,
`state/current.md`), archive `bible/00` + `bible/01`, and generate the digests — in **one** session, by reviewing a
table instead of reading the corpus.

## 2. Tag review (the only judgment-heavy step)

1. `propose-tags` (47-04) gives, per item: candidate areas + confidence, candidate amendment edges, candidate one-liner.
2. The agent prints **one review table per kind**, sorted with low-confidence items first:

   | id | title / lead (≤ 100 chars) | proposed areas | conf | amends / amended_by | one-liner (≤ 220) |
   |---|---|---|---|---|---|

3. For **low-confidence** items (and all ADRs whose candidate one-liner is > 220 chars or contains "see" / "refines"),
   the agent opens just that item with `genesis-ctx adr|lesson <id>` and fixes the row. High-confidence rows are
   accepted unless the user objects.
4. The user skims the tables (≈ 77 ADRs + 86 lessons + ~60 code-map sections) and answers objections in batches.
5. Accepted rows are written to `context/tags/{adr,lesson,codemap}.toml` (with `reviewed_fp`); `.proposed.toml` files
   deleted. `areas.toml` is finalized from the 47-02 proposal plus anything the review surfaced.

Rules for the one-liners: one imperative sentence; keep the ADR's operative words (e.g. "MANDATORY", "never",
"REQUIRED"); name the mechanism when it is the rule (e.g. "`env` is a LIST of `{name,value}`"); never drop a negation.
Lessons default to their bold lead verbatim (`rule = ""`); write a `rule` only when the lead is > 220 chars.

## 3. `context/L0-core.md` (≤ 4K tokens)

Sections, in order:

1. **What Genesis is** — the `bible/00` §0 paragraphs, verbatim.
2. **Where things are** — the five repos at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`, project-tracker at
   `/Users/ramaswamy.u/repo/project-tracker/genesis/`, the dev venv path; one line each.
3. **Retrieval protocol** —
   - The digests below list **every** ADR and lesson. Before acting on an area, get the full text:
     `genesis-ctx pack <sub-spec>` (or `--areas …`), or `genesis-ctx adr <id>` / `lesson <id>`.
   - Never open `reference/decision-log.md`, `bible/03`, `bible/04`, `bible/06` or `archive/**` whole; use
     `genesis-ctx` or ranged reads.
   - For history ("when/why did we…"), use `genesis-ctx search <term> --archive`, then the `progress/` doc.
   - If a digest line and a full text disagree, the full text wins; report the mismatch to the docs agent.
   - For heavy exploration (many files), use a sub-agent and keep only its summary.
4. **Key implementation contracts** — the bullets moved from `bible/04` (node signature, `build(ctx)`, standalone
   `graph.py`, ACP `env` list), verbatim.
5. **Non-negotiables in one breath** — five lines pointing at the digest classes ("ADRs are non-negotiable; flag and
   confirm any deviation", "lessons are do-not-regress", "ask before destructive actions", etc.), taken from
   `bible/04` §5 heading and `bible/07` §10.

## 4. `context/state/current.md` (≤ 4K tokens, overwritten every phase)

Sections: **Active phase** (one line, e.g. "none — Phase 47 complete" — read by `status --brief`); **Shipped versions**
(the five repos' tags + dependency chain, from `bible/01` §2 table — current values only); **DB version** /
`current_version`; **Test counts** at the last release (one line per repo); **What works today** (the `bible/01` list,
current items only, one line each); **Known open items** (pointers into `specs/backlog/`). No history, no CI ids.

Then archive `bible/00-onboarding-and-overview.md` and `bible/01-current-state.md` verbatim (one commit), re-run
`verify-lossless` (0 missing).

## 5. Generate

`genesis-ctx index` → `_generated/{adr-digest,lesson-digest,area-catalog}.md`; `genesis-ctx lint` green except the
manifest check for future specs (none exist yet).

## 6. Acceptance

- `lint` green; L0 total ≤ 15K tokens (printed by `lint`).
- `genesis-ctx pack --areas chat` produces a pack that contains ADR-031, -033, -034 and -045 (the chat amendment chain)
  and the chat lessons — spot-checked with the user.
- `verify-lossless` 0 missing.

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md",
        "tracker:specs/phase-47-agent-context-system/47-04-scripted-migration.md"]
```
