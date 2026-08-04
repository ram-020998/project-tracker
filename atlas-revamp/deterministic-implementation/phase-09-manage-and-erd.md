# Phase 9 — Manage Actions and ERD

| | |
|---|---|
| **Depends on** | Phase 8 (independent of the generation pipeline — **may run in parallel with Phase 8**) |
| **Outcome** | `dg erd-input` + externalized domain config; `dg` subcommands for the mechanical parts of manage |
| **Retires** | Hardcoded GSS taxonomy in `data-gen-erd/SKILL.md`; splits that skill into `SKILL.md` + `references/` |
| **Proposal refs** | §8 Phase 9; Appendix D-15 note (ERD domain assignment becomes a lookup) |

> Two independent tracks bundled: **ERD** (de-hardcode the domain taxonomy into config) and **manage**
> (schema exploration / query-validate / rollback mechanics). **Note the boundary:** this phase de-hardcodes
> ERD *input*; it does **not** rehome the `erd-gen` renderer — that personal-repo dependency (#19) is
> tracked separately as **DEC-3**.

---

## 1. Objective
- Convert ERD domain assignment from a hardcoded judgment call into a config lookup.
- Move the mechanical parts of the three manage actions into `dg`, leaving only `D14` routing to the model.

## 2. What to build

### 2.1 ERD
- Extract the hardcoded GSS domain patterns + color map from `data-gen-erd/SKILL.md` into:
  - `config/domains.example.json` — **committed**, GSS mapping as the worked example;
  - `config/domains.json` — **gitignored**, the active mapping.
- `dg erd-input` builds `<app>-erd.json` from `raw/{app_schema,schema_relationships}.json` + config.
- **Unmatched tables fall back to a single `Other` domain** (not an error).
- Split `data-gen-erd/SKILL.md` (236 ln) into a short `SKILL.md` + `references/`, matching its three sibling
  skills' structure.

### 2.2 Manage
`dg` subcommands for the **mechanical** parts only:
- `explore-schema` → schema rendering;
- `query-validate` → filter construction + result formatting;
- `rollback` → session preview rendering + reverse-order plan.
`D14` (route a manage request to `explore | query | rollback`) **stays with the model.**

### Subcommand
```
dg erd-input      # raw/{app_schema,schema_relationships}.json + config/domains.json -> <app>-erd.json
```

## 3. Step-by-step
1. Lift GSS patterns/colors out of `data-gen-erd/SKILL.md` into `config/domains.example.json`; add gitignore
   entry for `config/domains.json`.
2. Implement `dg erd-input` with the `Other` fallback.
3. Split `data-gen-erd/SKILL.md` into short SKILL.md + `references/`.
4. Implement the manage mechanical subcommands; keep D14 routing in prose.
5. Apply the Phase-8 four-part structure to the manage skill prose.
6. Add fixtures: one GSS app + one **non-GSS** app; add tests.

## 4. Defects resolved
- Removes the hardcoded GSS taxonomy (the reason ERD domain assignment was a "decision" at all — see the
  §5 note that `D15` disappears once this is config).

## 5. Retirements
- Hardcoded taxonomy in `data-gen-erd/SKILL.md`; the monolithic 236-line SKILL.md structure.

## 6. Done when
```shell
dg erd-input        # against the GSS fixture
diff <app>-erd.json tests/fixtures/expected-gss-erd.json      # reproduces committed output

dg erd-input        # against a NON-GSS fixture
# tables land in real domains, NOT all in "Other" — proving the hardcoding is gone
python3 -m pytest tests/test_erd_input.py tests/test_manage.py -v
```
- ✅ `dg erd-input` reproduces a committed `<app>-erd.json` for the GSS fixture.
- ✅ A **non-GSS** application places tables in real domains rather than all in `Other`.
- ✅ `data-gen-erd/SKILL.md` is split into short SKILL.md + references.

## 7. Risks & notes
- **#19 is NOT closed by this phase.** `dg erd-input` produces the ERD *data*; the actual Lucidchart render
  still runs through `erd-gen` (personal repo, `curl|bash` + Lucid token). Resolve DEC-3 (migrate to shared
  namespace / drop `data-gen-erd` / keep behind a flag) independently.
- The non-GSS fixture is what *proves* de-hardcoding — don't skip it.

## 8. Handoff to Phase 10
CI wires tests for the manage/ERD subcommands and the reference-integrity check across the rewritten prose.
