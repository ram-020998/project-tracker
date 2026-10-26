# Bug — genesis-workflows: two workflows' tests share a module name, so 11 tests never run in CI

> **Status:** ✅ FIXED 2026-10-26 in genesis-workflows `9cb061f` (recorded in 49-03 As built): both `tests/__init__.py`
> removed; `validate_library` gate 8 now fails on any `workflows/*/tests/__init__.py`; full-library collection 331 →
> 305, no duplicate ids. Ships with the 49-09 genesis-workflows release. · **Found:** 2026-10-26, 49-03 review
> (genesis-workflows `325cc23`) · **Repo:** genesis-workflows · Pre-existing; not caused by Phase 49.

## Symptom

In the full library run (`pytest -q workflows --ignore=workflows/_fixtures`, the CI command), the 11 tests of
`workflows/generate-business-map/tests/` never run, and the 37 tests of `workflows/feature-breakdown-analysis/tests/`
run twice. The pass count looks healthy, so nothing flags it.

## Cause (as reported by the 49-03 reviewer; re-verify before fixing)

Both workflows have a `tests/__init__.py`. Pytest's default import mode then imports both test files under the same
package-qualified module name, and the second one resolves to the first.

## Suggested fix

Delete both `tests/__init__.py` files (the other workflows' `tests/` folders have none), then confirm the full run's
count rises by 11 and that each test id appears once (`pytest --collect-only -q`). Add a CI check or a
`validate_library` rule that fails when two workflow test modules collide, and record the lesson via
`genesis-ctx add lesson` (the reviewer's lesson candidate).
