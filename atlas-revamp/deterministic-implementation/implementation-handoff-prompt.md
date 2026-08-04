# Implementation Handoff — Data-Gen Determinism (CONTINUATION, from Phase 10)

> Paste into the new agent session. Phases 0–9 are DONE; your job is **Phase 10 (CI)** + the follow-ups.
> Read the four §0 docs before touching anything. Everything is **uncommitted** — see §1.

You are the implementation agent continuing the conversion of the Appian **data-generation skill family**
from prose to a tested `dg` Python CLI (proposal: `proposal-source.md`, "Option 4 — agent-driven"). The heavy
lifting is done and green; finish CI, resolve the open follow-ups, and get it committed + into an MR.

## 0. Read first (source of truth)
Under `/Users/ramaswamy.u/repo/project-tracker/atlas-revamp/deterministic-implementation/`:
1. **`tracker.md`** — **§0 Snapshot** (at-a-glance), §1 phase status, §2 per-phase checklists, §4 defect log
   (all 15 CLOSED), §5 decisions (DEC-1…6), §6 session log. This is the live truth.
2. **`README.md`** — plan overview; §6 phase table now shows 0–9 ✅ / 10 ⬜; §10 program Definition of Done.
3. **`proposal-source.md`** — the authoritative proposal (§8 Phase 10, §2.1 a11y `check_rule_refs.py` precedent).
4. **`phase-10-ci.md`** — your primary spec.

## 1. Repo / branch / **UNCOMMITTED STATE (read this)**
- Code repo: `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os`, branch **`feature/atlas-data-generator`**.
- **Nothing from Phases 0–9 is committed** — all the `dg` CLI, schemas, configs, fixtures, goldens, and the
  rewritten prose are in the working tree only (per the standing "keep going uncommitted" instruction).
  Early on, confirm with the user whether to **commit the Phases 0–9 work** (recommended: one coherent
  commit, or per-phase commits) before/with Phase 10. Push to the **dev** fork only
  (`appian/dev/solutions-os`); MRs are opened by a human via the dev-fork UI link (token 403s on create).
- Do **not** force-push shared branches; `feature/atlas-data-generator` is the clean data-gen branch.

## 2. What already exists (Phases 0–9, all green)
- **`dg` CLI** at `.kiro/resources/data-generator/scripts/` — 10 modules: `dg.py` (CLI dispatch), `state.py`,
  `gate.py`, `scaffold.py`, `coverage.py`, `validate.py`, `sql_emit.py`, `footprint.py`, `fields.py`,
  `erd_input.py`. Subcommands: `init · state · gate · plan-writes · coverage-gate · verify-input · validate ·
  gen-sql · plan-footprint · build-footprint · check-fields · erd-input`.
- **Contracts:** `schemas/{payload-metadata,payload-file,payload-spec,state,decisions}.schema.json`,
  `config/thresholds.json`, `config/domains.example.json` (+ gitignored `config/domains.json`).
- **Tests:** `tests/test_{state,gate,scaffold,coverage,validate,sql_emit,footprint,fields,erd_input,cli}.py`
  → **89 passed, ruff clean**. `conftest.py`, `ruff.toml` (line-length 140), `.gitignore` present.
- **Fixtures:** `tests/fixtures/sourceselection-{exemplar,manual,bulk}/` (schema-valid). Goldens:
  `sourceselection-manual/reports/coverage-gate.md`, `sourceselection-bulk/out/bulk-data.sql`.
- **Prose:** 17 procedural files rewritten to the 4-part form — **480 lines total** (from 4,194), **`⚠️`=2**.
- **Defects:** all 15 Appendix-A rows CLOSED.

## 3. How to run the suite (there is no committed venv)
Python is externally-managed (PEP 668) — use a throwaway venv and **clean caches after** (they're gitignored
but keep the tree tidy):
```
cd .kiro/resources/data-generator/scripts
python3 -m venv /tmp/dgvenv && /tmp/dgvenv/bin/pip install -q pytest ruff jsonschema
/tmp/dgvenv/bin/python -m pytest tests/ -q
/tmp/dgvenv/bin/ruff check *.py tests/
rm -rf /tmp/dgvenv __pycache__ .pytest_cache .ruff_cache tests/__pycache__
```

## 4. Your work — Phase 10 (CI) — see `phase-10-ci.md`
Add to `.gitlab-ci.yml` (wire incrementally; keep jobs fast/independent):
1. **test + lint** — `pytest` and `ruff` over `<dg-root>/scripts/` (use the existing `ruff.toml`).
2. **schema-lint** — validate every committed fixture artifact against `scripts/schemas/*.json` (catches
   contract drift). Also re-assert the two goldens replay byte-identical (`coverage-gate.md`, `bulk-data.sql`).
3. **reference-integrity** (spirit of a11y `check_rule_refs.py`) — fail if a step file names a `dg` subcommand
   that doesn't exist, **or** a subcommand exists that no step file invokes. Build a stable subcommand
   enumeration into `dg` (e.g. `dg --list-commands`) rather than a brittle grep. **Note:** the proposal's
   "each subcommand referenced by exactly one step file" is stricter than what holds today (e.g. `validate`
   and `check-fields` legitimately appear in both manual step-5 and exemplar E4); decide with the user
   whether to enforce "≥1 and exists" (recommended) vs strict "exactly one".
**Done when:** an MR that renames a subcommand without updating prose fails CI; a fixture/schema mismatch fails CI.

## 5. Follow-ups after Phase 10 (confirm scope with the user)
- **Commit + open the MR** (dev fork) once CI is green. Update `tracker.md` (Phase 10 → DONE; program DoD).
- **DEC-3 / issue #19 (OPEN):** the ERD **renderer** (`erd-gen`) is a personal repo (`ram-020998/erd-gen`)
  installed via `curl|bash` + a Lucid token. Phase 9 only de-hardcoded the ERD *input*. Decide: migrate
  `erd-gen` to a shared namespace, drop `data-gen-erd`, or keep behind a flag.
- **User-membership check** — implemented in `validate.py` but excluded from the default gate (name-based
  type inference false-positives like `groupAssignee`; needs full `record_properties` type=User + a current
  `users.json`). Enable it in CI once full `raw/` is captured.
- **Full `raw/` parity** — exemplar/manual fixtures use table-scoped `raw/` (DEC-6). If you want the full
  golden-replay of later phases end-to-end on a fixture, capture the remaining `record_properties/*`,
  `field_map.json`, `reference_data.json`, `documents.json`, `exemplar/*.json` per `tests/fixtures/README.md`.
- **DEC-5** — the full Option-4 pipeline is now built (beyond the "Option 3" milestone); confirm the team is
  good with that scope.

## 6. Guardrails / conventions
- **Scripts are pure functions over on-disk artifacts — NEVER call MCP/network from a `.py`.** The agent does
  all I/O to `raw/`.
- Keep **ruff clean** (line-length 140; imports grouped — `conftest.py` handles test path). Watch for `%` in
  argparse help strings (crashes py3.14 parser build — there's a `tests/test_cli.py` regression guard).
- Every phase: tests green + ruff clean + **update `tracker.md`** (status, checklist, session log) + clean caches.
- Prose retirements for Phases 1–7 were batched into Phase 8 (done). Don't re-add emphasis apparatus; `⚠️` is
  for genuinely destructive ops only.
- MCP tools available if needed (Atlas + Data Generator) — verified reachable, SourceSelection present.

## 7. Start here
1. Read `tracker.md` §0 + `phase-10-ci.md`.
2. Confirm with the user: **commit Phases 0–9 now?** and the reference-integrity strictness (§4 note).
3. Run the suite (§3) to confirm the inherited state is green before adding CI.
4. Implement the three CI jobs; verify the "Done when"; update the tracker; then handle §5 follow-ups.
