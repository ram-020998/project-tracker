# 31-01 — Research & format study (skill + example breakdowns + code audit)

> **Status:** ✅ DONE (2026-09-04) — findings captured in `31-01-findings.md`. · Part of Phase 31. **Docs only.** Gate: ⭐ user review (done — the design was reviewed + approved in the planning conversation).

## Purpose

Ground the phase in real authorities before locking the design: (a) the `spec-to-backlog` Kiro skill's
**analysis methodology**, (b) the real GSS **example breakdowns**, and (c) the existing **reuse surface** in
code. Extract only what we keep; explicitly list what we drop.

## Deliverables

- **Skill study** — clone `https://gitlab.appian-stratus.com/allison.olson/spec-to-backlog` (via `glab`/SSH),
  read every skill file, and extract: the two-phase (analysis → render) architecture, the **`Backlog_JSON`**
  contract (Story-Map vs Full-Breakdown depths), the **Appian-native story-breakdown best-practices**, the
  story-writing guidelines (As-a/I-want/So-that; AC style; INVEST), the readiness-check categories, and the
  **Sheets/Jira column contract** (`backlog-to-sheets.md` + `scripts/backlog-to-jira.py`). **Explicitly drop**
  the Lucid/Google-Sheets renderers, the Jira REST importer, `gws`/Lucid input fetching, and the team-profile
  /style-reference machinery.
- **Example study** — read the four GSS "Feature Breakdown Sheet" PDFs + the CSV at
  `/Users/ramaswamy.u/Documents/GSS/breakdown-examples`; extract the **real** field set, the **form vs
  process-model** split, **entry-point** granularity, the **Story vs Task** distinction, the **Dev Note**
  column, and the AC style actually used (Gherkin in the newest sheet).
- **Code audit** — confirm the reuse surface: m0015 `StageStore`, `stages.ts` `breakdown` reservation,
  `deriveAvailability` (prerequisites), the `technical-design-analysis` workflow skeleton, the generalized
  `StageFinalizer` `_BINDINGS`, `mode_profile.py`, the `api/features.py` stage endpoints (`_launch_td`,
  `_launch_analysis`, `export.md`, `_td_prereqs_ready`), the ADR-035 upload path, and the pinned `openpyxl`.
- **Findings doc** — `31-01-findings.md` records the extracted methodology + schema + Jira mapping + code map.

## Gate

⭐ User review of the findings + the proposed design (workflow shape, backlog schema, HTML output, gating,
export). Approved 2026-09-04 → 31-02 (ADR & finalize).
