# 47-10 — Release and onboarding (the switchover)

> **Status:** ✅ BUILT 2026-10-20 (As built below). Repo: project-tracker. Parent: `specs/phase-47-agent-context-system.md`.
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

## As built (2026-10-20, main session — at the user's request, no extra agent sessions)

- **Archived verbatim first** (lossless): `archive/agent-onboarding-pre-47.md`, `archive/bible-07-pre-47.md`,
  `archive/bible-02-pre-47.md`, `archive/bible-chunk-headers-pre-47.md` (the old "read every chunk" headers of bible/03,
  04, 05, 06, 08), and the superseded Phase-47 SPEC-DRAFTED entries (appended to `archive/bible-08-shipped-phases.md` and
  `archive/tracker-status-log.md`).
- **§1.2** new `AGENT_ONBOARDING.md` (~1.3K tokens): human launch commands, the any-agent fallback load order, where
  knowledge lives. **§1.3** `bible/07` §8 step 7 → As-built + docs-agent write-back; §10 + "never read the bulk files
  whole" and "never --trust-all-tools". Beyond the spec: the "read every chunk" chunk headers of bible/02, 03, 04, 05,
  06, 07, 08 replaced with a context-layer header (02 and 07 are in L0, so the old instruction contradicted ADR-077).
- **§1.4** README "Start here" + phase row 47 (SHIPPED) + status-source note. **§1.5** ADR-077 Accepted via
  `genesis-ctx add adr --phase 47` (areas release-ci, security). **§1.6** L-087, L-088 via `add lesson --phase 47`.
- **§1.7** `context/state/current.md` active phase → none; agent-system line; `context/changelog.md` created; tracker §6
  SHIPPED entry (≤5 lines); bible/08 SHIPPED block; `progress/phase-47-agent-context-system.md`.
- **§1.8** OPERATOR_GUIDE → FINAL (pilot carried into Phase 48). **§1.9** index + lint green; strict verify-lossless
  0 missing; update.sh run (m6 fix). **§1.10** committed; pushed on the user's instruction to update everything.
- Umbrella + 47-09 + 47-10 Status lines → SHIPPED / BUILT.
