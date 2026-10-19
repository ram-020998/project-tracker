# 47-08 — Examination of every area

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Agent:
> `genesis-migration-examiner`; grading by `genesis-migration-reviewer`; fixes by `genesis-migration-writer`.

## Unit of work = one area's exam
1. **Answer** (examiner): every question whose units have this primary area, from `knowledge/_build/` only, citing
   the built document and heading for each answer. "Not in the documents" is a valid answer and is recorded as a
   miss, never guessed around. Output `migration/exams/<area>.answers.jsonl`.
2. **Grade** (reviewer): each answer against the question's `answer_points` and its units → correct / partial /
   wrong / missing, with the cause (extraction, reconcile, writing, question). Report as a normal review.
3. **Fix** (writer) every miss; **re-examine** the missed questions plus a fresh 10% random sample of the area.

## Router test (once, after all areas)
The examiner gets only `CORE.md` and 40 task descriptions (from past phases' sub-specs, written by the
orchestrator), and names the areas and rules each task needs; graded against `gk context` and the reviewer's
judgement. Misses → fix the router or the area globs.

## Definition of Done
Per area 100% of high-stakes questions correct and ≥ 95% overall after fixes · router test ≥ 95% with every miss
explained · reports in `migration/reviews/`.

## Verification
The grading itself is the review. In addition the reviewer re-grades a random 10% of each exam it did not grade
(another reviewer session) to check grading consistency.
