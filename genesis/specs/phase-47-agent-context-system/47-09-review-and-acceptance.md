# 47-09 — Review, evaluation and pilot

> **Status:** 🟡 SPEC-DRAFTED 2026-10-20. Repo: all of Phase 47. Parent: `specs/phase-47-agent-context-system.md`.
> Session S6 — run **with the new agents** (dogfood).

## 1. Independent review (`genesis-review`, read-only)

Scope: `agent-system/**`, `context/**`, the migration commits. Checks: `genesis-ctx` and installer tests green; every
47-0x acceptance item; permissions really block what §3 of 47-06 says (try `git push` from `genesis-dev` → denied;
a write under `{{REPOS}}` from `genesis-docs` → denied); no secrets in any profile; `verify-lossless` 0 missing.
Report: `specs/phase-47-agent-context-system/reviews/47-09-review.md`, verdict SHIP / NEEDS_CHANGES.

## 2. Golden-question eval — "nothing is missed"

`context/eval/golden.toml`, ~40 questions with the expected ids and a key phrase, written by the review agent from the
**tag tables** (not from memory), e.g.:

```toml
[[q]]
ask      = "May the chat write files? Where?"
expect   = ["ADR-031", "ADR-034"]
phrase   = "sandbox"
critical = true
```

Spread: ≥ 1 per area; ≥ 10 `critical` (security, read-only chat, reliability trio, pre_mutation gate, no deletes in the
Implementation lane, ADR-019 release order, localhost guardrail, ACP `env` list, `web/static` commit, migrations only).

Run: a fresh `genesis-dev` session per batch of 10 (headless where CLI 3 allows, otherwise interactive), prompt "Answer
each; cite the ADR/lesson ids; use genesis-ctx as you normally would." A script grades id + phrase presence.
**Pass: ≥ 95 % overall and 100 % of `critical`.**

## 3. Recall replay on Phase 46 — "the pack would have included it"

For each of 46-02 … 46-09: write the context manifest the spec agent would have written (areas + code paths from the
sub-spec's own text), run `genesis-ctx pack`, and compare the pack's ADR/lesson set with every `ADR-NNN` cited in that
sub-spec, its As-built and the 46-10 review. **Pass: 100 % recall** (precision reported, not gated). A miss → fix the
tags/areas, never the expected set.

## 4. Context measurement

From the root workspace: fresh `genesis-dev`, `/context show` → record the % before and after `genesis-ctx pack` for a
46-sized sub-spec. Also record a **baseline**: a plain `kiro-cli --v3` session (no agent) with the same prompt. The
**Genesis share** = session total − baseline. **Pass (gated on the Genesis share): ≤ 5 % before the pack, ≤ 10 %
after.** Same for `genesis-spec` at the start of a spec session (share ≤ 5 %). Session totals are recorded for
information only, not gated (47-01 §5.7).

## 5. Live pilot

A small, real task from `specs/backlog/` chosen by the user, run end to end with the operator guide: spec → one dev
sub-spec → review → (release only if the user wants) → docs. Record context % at each session start, and anything in the
guide that was unclear (fixed in 47-10).

## 6. Acceptance

All four gates (§2–§5) pass; review verdict SHIP; findings fixed or deferred with the user's agreement.

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system.md", "tracker:agent-system/OPERATOR_GUIDE.md"]
```
