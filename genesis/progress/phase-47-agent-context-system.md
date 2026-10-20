# Phase 47 — Agent Context System — as built

> **Status:** ✅ SHIPPED 2026-10-20 · project-tracker only (no Genesis code repo change, no Genesis tag) · ADR-077 Accepted.
> Spec: `specs/phase-47-agent-context-system.md` + `47-01..47-10` (each sub-spec has its own As-built section).
> Review: `specs/phase-47-agent-context-system/reviews/47-09-review.md` (rounds 1–3, verdict **SHIP**).
> Follow-ups: `specs/backlog/phase-47-follow-ups.md`. Operator guide: `agent-system/OPERATOR_GUIDE.md`.
> Commits: project-tracker `main`, `b127a4d` (spec) … `b97fa45` (review) + the 47-10 switchover commit.

## What changed for the user

- No more "read the bible". Five role agents, launched from `~/repo-gitlab/ramaswamy.u` with
  `kiro-cli --v3 chat --agent genesis-<spec|dev|review|release|docs>`.
- A fresh agent starts at **≈1.5 %** Genesis share of a 1M window (≈5.5 % total incl. Kiro's own prompt and tools),
  down from 45–50 % plus task specs. A 46-sized sub-spec's pack adds 3–6 % (47-09 §4).
- Every ADR and lesson is still visible every session (one-line digests in L0); full text arrives deterministically via
  `genesis-ctx pack` / `adr` / `lesson`.

## Delivered (by sub-spec)

| Sub-spec | Result |
|---|---|
| 47-01 | Findings: measurements (1,124,035 bytes mandatory), research, options, decisions (rounds 1–9 in §5) |
| 47-02 | `context/`, `archive/`, `agent-system/` layout; tag/area/manifest formats; anchor rules for the real files (### ADRs, bullet-form ADRs, amendment headings, bold-line code-map sections) |
| 47-03 | `genesis-ctx` (stdlib Python): status, pack, check, adr, lesson, area, search, index, lint, add, mark, archive, propose-tags, propose-b04, verify-lossless |
| 47-04 | Move-only migration: tracker §6 (354 KB), bible/08 shipped blocks (132 KB), onboarding banners (14 KB) → `archive/`; lesson markers L-001..L-086; 0 of 1,338 baseline units missing (`archive/LOSSLESS.json`) |
| 47-05 | Reviewed tags for 76 ADRs, 86 lessons, 46 code-map sections; 22 areas with gates; `L0-core.md`; `state/current.md`; bible/00 + bible/01 archived |
| 47-06 | Five JSON V3 profiles, ten skills, hooks (SessionStart status, bulk-read guard, Stop lint); live CLI-3 probe |
| 47-07 | `install.sh` / `update.sh` / `uninstall.sh` (manifest + sha256, backups, dry run, foreign-file refusal); installed |
| 47-08 | Documentation standard; `add adr|lesson --phase` in the house format; `genesis-doc-writeback` skill |
| 47-09 | Review rounds 1–3 (see below); golden 50/50; recall 84/84 (union); context bars met |
| 47-10 | Switchover: new `AGENT_ONBOARDING.md`; bible/07 step 7 + §10; "read every chunk" headers replaced (originals archived); ADR-077; L-087/L-088; state, changelog, README, tracker, bible/08; operator guide final |

## Review history (47-09)

- **Round 1 — NEEDS_CHANGES:** shell allow rules let read-only agents write (`cat x > path`) and `/usr/bin/git … push` /
  `env git … push` bypassed the push deny (B1/M1); recall 91.7 % (3 tags); packs 14–20 % with a 1.7× low token estimate.
- **Fixes:** `shell-guard.sh` PreToolUse hook (holds even under `--trust-all-tools`); 3 tag fixes; calibrated estimator
  (chars ÷ 2.5) and two-tier packs (full text for direct hits + chains, one line for area-only hits); minors.
- **Round 2 — NEEDS_CHANGES:** shell-guard over-blocked `2>/dev/null`, `2>&1`, quoted `>` (M5); retrieval batch denied
  non-interactively (m9). **Fixes:** quote-aware guard + positive command corpus; one-call multi-id retrieval form
  (m9 0/10 → 10/10); stop-lint timeout.
- **Round 3 — SHIP:** M5/m7 verified; m6 (dev → review sub-agent without a prompt) needed a `subagent` permission rule —
  V3 ignores `trustedAgents` for approval — fixed and verified live (`f2b2150`). B2 (allow-listed commands that write
  through flags, e.g. `ruff format`, `--output=`) **accepted by the user as a known minor** → backlog.

## Decisions taken with the user (full list: 47-01 §5)

Curated active layer + verbatim archive; agents installed globally from project-tracker with install/update scripts;
five roles incl. documentation; Kiro CLI 3; move-only migration; launch from the root workspace; `claude-opus-5.5`
pinned; recall-first tagging; closure = transitive amended_by/superseded_by + one-hop amends from seeds; budgets
gated on the Genesis share; B2 accepted; the live pilot carried into Phase 48.

## Deviations from the spec

- Agent profiles are **JSON**, not Markdown (the V3 "universal" format).
- Skills are listed by absolute path in each role prompt (V3 doesn't register profile `skill://` on `chat --agent`).
- Token budgets rescaled after calibration: L0 cap 24K (was 15K estimated), state 6.4K; pack warn 60K / fail 120K.
- Bars gated on the Genesis share (total minus a plain V3 session), totals recorded for information.
- The separate pilot (47-09 §5) moved into Phase 48.

## Evidence

agent-system pytest 229 passed; `genesis-ctx lint` 0 errors / 0 warnings (L0 ≈20.2K / 24K); strict
`verify-lossless --baseline d89f763` 0 missing; installed files match the manifest; live checks recorded in the review.

## Lessons

L-087 (migrate by moving + sidecar index; probe the real CLI first) and L-088 (command-parsing shell guard with bypass
AND positive corpora) in `bible/06`.
