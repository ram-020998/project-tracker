# 47-03 — Pilot: collaboration & Hub, all four passes

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Agents: extractor → writer →
> examiner, each session reviewed. **Gate: GO / NO-GO** by the user on the pilot report.

## Why this area
It is rich in every high-stakes type — three ADRs (063, 064, 065), a frozen API contract with fixtures and two
additions, lessons, procedures (Hub validation, deployment) — and it is self-contained enough to measure.

## Sources (sizes at 2026-10-19; 47-01's `batches.yaml` is authoritative)
| Batch | Sources | ~chars |
|---|---|---|
| **P1** | `specs/phase-35*` (+ sub-specs), `specs/phase-37*`, `specs/phase-38*`, `progress/phase-35/37/38-*`, `reference/decision-log.md` ADR-063…065 range | ~145K |
| **P2** | `specs/phase-36-genesis-hub-appian-app*` (incl. `contract/` docs + `fixtures/*.json`), `progress/phase-36-*` | ~165K |

Collaboration knowledge that lives in other files (bible chunks, tracker, later phases) is extracted in 47-04 and
folded in when the area is rewritten in full in 47-06. The pilot's pack is therefore a **pilot draft**; its
purpose is to prove and tune the method.

## Sessions (each followed by a review)
1. **Extract P1** (extractor, extract mode).
2. **Extract P2** (extractor).
3. **Questions P1+P2** (extractor, question mode): one question per high-stakes unit, every lesson as a scenario,
   plus 20 INFO-level questions.
4. **Reconcile** (writer, reconcile mode) over the pilot units: fates, exact checks against the code, conflicts.
   The orchestrator brings RULE/DECISION/CONTRACT conflicts to the user.
5. **Write** (writer, write mode): `rules/ADR-063|064|065.md`, the pilot's lesson files, `areas/collaboration-hub/
   pack.md` and `reference/` (the Hub contract as current state: kinds, fields, the additions merged in, error
   semantics, the CAS/versioning rules), then `gk build`.
6. **Examine** (examiner) — every pilot question from `_build/` only; the reviewer grades.
7. **Pilot report** (orchestrating session) → `migration/reports/47-03-pilot.md`.

## The pilot report must contain
- Per session: chars read, units produced, units per 10K chars, context used at the end (`/context`), duration.
- Review results: verdicts, findings by severity, every PROCESS finding and the method change it led to.
- Exam: score overall and on high-stakes; every miss with its cause (extraction, reconcile, writing, question).
- Copy-check and coverage results; conflicts found and how they were decided.
- A re-estimate of 47-04 … 47-08 (sessions, risks) from the measured rates.
- A recommendation: GO, GO with changes (listed), or NO-GO (what to redesign).

## Definition of Done
Every pilot session reviewed PASS or PASS WITH FINDINGS · exam 100% on high-stakes, ≥ 95% overall, misses fixed ·
`gk validate`, `copycheck`, `exact`, `budget` green on the pilot store · the report written · the user's decision
recorded in `PROGRESS.md`.

## Verification (reviewer, on the final pilot state)
The umbrella §6 standard over the whole pilot, with **all** pilot DECISION/CONTRACT units traced source → ledger →
new doc, and a read of the pack as a newcomer: could you implement a change to the collaboration service from the
pack + reference alone without breaking a rule? List what was missing.
