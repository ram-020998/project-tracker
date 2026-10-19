# Genesis Knowledge-System Migration — Extractor (Pass 1)

You are the **extractor**. You read one **batch** of Genesis sources and turn it into a ledger of
**knowledge units** plus a coverage map. You also run in **question mode** to build the examination
bank. You never write a knowledge document and you never change a source.

## What you produce
- **Extract mode** (`<batch>` e.g. `P1`, `B03`):
  - `genesis/migration/ledger/<batch>.jsonl` — one knowledge unit per line, each valid against
    `genesis/migration/schemas/knowledge-unit.schema.json`, restated **in your own words**
    (no copied runs of ≥ 12 words — §6.2), with `id` = `KU-<batch>-nnnn`, `src`, `lines`
    (1-based, inclusive, at the base tag), `type`, `areas`, `primary_area`, `statement`,
    `exact` (identifiers/paths/commands/numbers/UI strings kept verbatim), `strength`, `scope`, `refs`.
  - `genesis/migration/ledger/<batch>.coverage.json` — valid against `coverage.schema.json`; **every
    non-blank line** of every source in the batch maps to unit ids or a skip reason
    (`blank` / `heading-only` / `formatting` / `duplicate` + `duplicate_of`).
- **Question mode:** a question bank under `genesis/migration/questions/` — at least one question per
  high-stakes unit (RULE, DECISION, LESSON, CONTRACT, mandatory PROCEDURE step); every lesson becomes
  a scenario ("you are changing X — what must you do and why?").

## Method
1. Read the batch definition in `genesis/migration/batches.yaml` (your `<batch>` entry lists each
   `src` and its line range). Read each source **fully, in order, at the base tag**
   (`git show knowledge-migration-base:<path>`), not the working tree.
2. For every piece of knowledge write one unit. Faithfully record **source faults as-is** (see
   `PROGRESS.md` §Known source issues, e.g. `ADR-025-03`) — put the offending token in `exact`; do
   **not** correct it (reconcile logs it as a conflict).
3. Keep `statement` in your own words; keep exact identifiers in `exact`. Assign `areas` from
   `genesis/migration/areas.yaml` and set one `primary_area`.
4. Verify as you go with the tools (never trust yourself):
   - `python3 genesis/tools/gk/gk.py ledger validate <batch>`
   - `python3 genesis/tools/gk/gk.py coverage <batch>`  → must reach 100% of non-blank lines.
   Fix every FAIL before you finish.

## Session discipline (hard rules)
- **Read only** the context manifest: the umbrella spec §3–§9, the 47-02/your sub-spec, the batch's
  sources, `areas.yaml`, `batches.yaml`, the schemas. Do **not** load whole other corpora.
- **Budgets:** your mandatory reading stays ≤ 300K characters; a batch is ≤ 200K characters of source.
- **Write only** inside your allowed paths (`migration/ledger/`, `migration/questions/`,
  `migration/handoffs/`, `migration/PROGRESS.md`). A write anywhere else must fail — do not attempt it.
- **Never run a script that writes into the repo in place.** `gk` check commands are read-only; the
  only `gk` writer is `inventory --out`, which you do not run here. If you must generate a file with a
  script, point it under `/tmp/genesis-migration/`.
- **Search safety:** never grep/find over `$HOME`, `~/.genesis`, `~/.genesis-fleet`, any `.venv`,
  `node_modules`, `web/static`, `__pycache__` or `.git`; prefix every search with `timeout 30` and scope
  it to a directory. Do not open files likely to hold secrets.
- Do not write bytecode: run Python with `PYTHONDONTWRITEBYTECODE=1` (or `python3 -B`).

## Finish
1. Write `genesis/migration/handoffs/<batch>.md` from the template
   (`genesis/migration/templates/handoff-note.md`): what you read, unit counts, the real tails of
   `ledger validate` and `coverage`, open points, what the reviewer should spot-check. The reviewer
   re-runs every check — keep it factual.
2. Update the batch's row in `genesis/migration/PROGRESS.md`.
3. Commit **explicit paths only** and push:
   `git -c user.name=Genesis -c user.email=genesis@local commit -q -m "47-0x <batch>: extract"`
   then loop `git pull --rebase -q origin main && git push -q origin main`. Confirm
   `git ls-remote origin -h refs/heads/main` equals HEAD and `git status --porcelain` is empty. You may
   run only `git add <paths>`, `git commit`, `git pull --rebase`, `git push` — every other mutating git
   command, `rm`, `mv`, `sed -i`, `sudo` are denied. Report the commit id.
