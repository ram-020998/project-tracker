# Phase 2 — Scaffold (`dg init`)

| | |
|---|---|
| **Depends on** | Phase 1 (`state.py` API + enum) |
| **Outcome** | `scaffold.py` + `dg init`: one command creates the request folder, all artifacts, `state.json`, `decisions.json` |
| **Retires** | `step-0-initialize.md` — **442 → ~40 lines** |
| **Proposal refs** | §8 Phase 2; Appendix D-7 (6-vs-7), D-15 (cwd) |

> `step-0` is the single largest file (442 lines) and is ~90% bucket-A scaffolding. It also contains the
> project's most embarrassing contradiction (D-7: "ALL 7 FILES" and "All 6 files. No exceptions." in the
> same file). Code owning the artifact list makes the contradiction structurally impossible.

---

## 1. Objective
Turn folder+artifact creation into one deterministic command driven by decision `D1` (the parsed request).

## 2. What to build — `scaffold.py`
1. **Create the request folder**: `data-requests/{YYYY-MM-DD}_{slug}[-{NN}]/` with subdirs `raw/`,
   `raw/record_properties/`, `raw/exemplar/` (exemplar mode), `payloads/`, `reports/`, `out/` (bulk mode).
2. **Mode-dependent artifact set from ONE list in code** (fixes **D-7**): manual = 7 artifacts,
   exemplar = 5 artifacts. There is exactly one canonical list; the count is derived, never asserted twice.
3. **Same-day collision handling** (fixes part of D-7's confusion): if the slug folder exists, append
   `-02`, `-03`, … .
4. **Anchor the folder to the repository root, not `os.getcwd()`** (fixes **D-15** — `step-0` §0b said
   "current working directory," which is undefined for an agent session). Resolve repo root deterministically
   (walk up to the `.git` dir or an explicit `--root`).
5. **Write initial `state.json`** (all steps `PENDING`, `gate_mode` unset) and **`decisions.json` seeded from
   `D1`** (`{app, entity, target_status, conditions[], volume, mode}`).
6. **Record `seed` and `date_anchor`** at init. Defaults: `seed = int(YYYYMMDD)`, `date_anchor = today`. Both
   overridable via `--seed` / `--date-anchor`. (Sets up D-10/D-11 fixes consumed in Phase 7.)

### Subcommand
```
dg init --request-json <decisions.json#D1> --mode manual|exemplar --seed N [--date-anchor YYYY-MM-DD] [--root <path>]
```

## 3. Step-by-step
1. Implement the canonical artifact list (manual/exemplar) as data in `scaffold.py`.
2. Implement slug derivation + `-NN` collision suffixing.
3. Implement repo-root anchoring.
4. Write `state.json` (via `state.py`) and `decisions.json` (validated against the Phase 0 stub schema).
5. Reduce `step-0-initialize.md` to ~40 lines: describe `D1` and how to invoke `dg init`; delete the
   6-vs-7 apparatus, the STOP banner, and the tracker template.
6. Add `tests/test_scaffold.py`.

## 4. Defects resolved
- **D-7** — 6-vs-7 contradiction gone (one list in code).
- **D-15** — folder anchored to repo root, not cwd.
- Sets up **D-10/D-11** (seed + date_anchor recorded here; enforced in Phase 7).

## 5. Retirements
- `step-0-initialize.md` **442 → ~40 lines** of prose (describe D1 + invoke `dg init` + what to do on error).

## 6. Done when
```shell
dg init --request-json d1.json --mode manual --seed 20260729
diff -r data-requests/2026-07-29_eval-complete/ tests/fixtures/expected-scaffold-manual/   # no differences

dg init --request-json d1.json --mode exemplar --seed 20260729
# produces exactly 5 artifacts; asserts analysis.md and coverage-gate.md are ABSENT

python3 -m pytest tests/test_scaffold.py -v
```
- ✅ Manual init reproduces the expected 7-artifact scaffold byte-for-byte (`diff -r` clean).
- ✅ Exemplar init produces exactly 5 artifacts (no `analysis.md` / `coverage-gate.md`).
- ✅ Two consecutive `dg init` with the same slug produce `…_eval-complete` and `…_eval-complete-02`.
- ✅ `state.json` starts all-`PENDING`; `decisions.json` carries `D1`.

## 7. Risks & notes
- Slugging must be deterministic and filesystem-safe (lowercase, hyphenate, strip punctuation). Pin the
  algorithm and test it, or fixtures won't reproduce.
- Repo-root resolution must not depend on where the agent happened to launch. Prefer `--root` when in doubt.

## 8. Handoff to Phase 3
Phase 3 (coverage gate) assumes the folder/artifact layout and `state.json` shape created here.
