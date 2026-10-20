---
name: genesis-live-acceptance
description: Use when running live acceptance of Genesis — the fleet + Playwright procedure, the HITL stop rule, evidence screenshots, and backing up the DB before a fleet update. For the genesis-review (and genesis-dev) agent.
---

# Live acceptance

Procedure & precedent: `{{TRACKER}}/bible/05-dev-loop-and-release.md` (the acceptance/fleet section) and the latest
shipped phase's review/acceptance sub-spec (`genesis-ctx search "live acceptance" --archive` to find it). Scripts you
write go in `/tmp` (Playwright drivers); you are read-only on the repos.

## Procedure
1. Bring up the app locally per the dev loop; confirm the version and DB version with `genesis-ctx status` and the app's
   own report.
2. Drive the real UI with Playwright from `/tmp` (node scripts), exercising the acceptance scenarios the sub-spec lists.
3. Capture **evidence**: screenshots and the relevant DB/API state for each scenario, saved under `/tmp/genesis-review/`.

## HITL stop rule (do not skip)
Stop at EVERY human-in-the-loop gate and ask the operator before proceeding — especially before any **fleet update**,
any data mutation, or anything that touches a shared/"prod-like" target. Never auto-approve a workflow's own HITL gate;
only relay the human's decision.

## Backups
**Back up the database before a fleet update** (and before any migration against real data). Record where the backup is
in the evidence.

## Report
Feed results into the review report (genesis-code-review skill): each scenario PASS/FAIL with the evidence path. A failed
acceptance scenario is at least a major finding.
