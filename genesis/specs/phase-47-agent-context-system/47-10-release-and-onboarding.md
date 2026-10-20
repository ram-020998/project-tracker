# 47-10 — Release and onboarding (the switchover)

> **Status:** 🟡 SPEC-DRAFTED 2026-10-20. Repo: project-tracker. Parent: `specs/phase-47-agent-context-system.md`.
> Session S6, after 47-09 passes. Switch only on the user's go-ahead.

## 1. Switchover

1. **Archive** the pre-switch `AGENT_ONBOARDING.md` verbatim to `archive/agent-onboarding-pre-47.md`.
2. **Rewrite `AGENT_ONBOARDING.md`** (≤ 1.5K tokens): what the agent system is; "use the Genesis agents
   (`kiro-cli chat --agent genesis-<role>`) from the root workspace — do not read the bible"; the L0 file list; the
   operator-guide link; for an agent **without** the profiles (e.g. a plain `kiro_default` session), a fallback: "read
   the L0 files listed here, then use `genesis-ctx` (path) as the retrieval protocol says".
3. **Edit `bible/07`**: §8 step 7 "Document" → "Record the As-built section in the sub-spec; the documentation agent
   does the phase write-back (`agent-system/skills/genesis-doc-writeback`)"; §10 adds "Never read the bulk files whole;
   use `genesis-ctx`". (Verbatim elsewhere.)
4. **`README.md`**: "Start here" points at `AGENT_ONBOARDING.md` + the operator guide; the phase-47 row.
5. **ADR-077** → Accepted in `reference/decision-log.md` (via `genesis-ctx add adr`) with tags.
6. **Lessons** from the build (e.g. move-only migration cost ∝ index, one routing level) via `genesis-ctx add lesson`.
7. `context/state/current.md`: active phase "none — Phase 47 complete"; `changelog.md` line; ≤ 5-line tracker §6 entry;
   `progress/phase-47-agent-context-system.md` (as-built, cited).
8. **Operator guide**: finalize `agent-system/OPERATOR_GUIDE.md` with the pilot's findings; mark "Final".
9. `genesis-ctx index && lint` green; `verify-lossless` 0 missing; `update.sh` (install already done in S5).
10. Commit project-tracker; push **on the user's go-ahead**.

## 2. Rollback

`uninstall.sh`; `git revert` the 47 commits (archive moves are separate commits, so the mandatory set can be restored
independently of the agents).

## 3. Acceptance

The next real phase (48) is specced and built with the new agents; the user confirms the starting context of each
session matches 47-09 §4.

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-08-documentation-standard.md",
        "tracker:specs/phase-47-agent-context-system/47-09-review-and-acceptance.md"]
```
