#!/usr/bin/env python3
"""Phase 47-01 — batch plan check (47-01 DoD).

Verifies ``migration/batches.yaml`` against ``migration/inventory.csv``:

* the union of batch line ranges == **all** ``extract`` lines — every extract
  file is present and each of its lines is covered **exactly once** (no gap, no
  overlap);
* **no** ``archive-only`` file appears in any batch;
* every batch's total chars <= the declared ``char_limit`` (<= 200,000, lowered
  from 250,000 at the 47-01 gate, 2026-10-19);
* recorded per-entry chars are self-consistent (split chunks of a file sum to
  the file's inventory char count);
* batch ids are unique; P-batches and a contiguous B01..Bnn series exist;
* **boundary safety (47-01 review P1):** every internal split boundary of a
  multi-entry source lands on a safe point (blank / heading / between sibling
  list items), never inside a fenced code block — read from the base-tag blob.

**One implementation (47-02 review M1):** the tiling + cap + boundary logic lives
once in ``genesis/tools/gk/core.check_batches_all``; this script and
``gk batches check`` both call it, so they can never diverge.

Exit status is non-zero on any violation.

Run:  python3 genesis/migration/scripts/check_batches.py
"""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "genesis" / "tools" / "gk"))
import core  # noqa: E402


def main() -> int:
    inventory = core.load_inventory()
    batches, char_limit = core.load_batches()
    errs, st = core.check_batches_all(inventory, batches, char_limit)

    print(f"batches: {st['batches']}  (pilot {st['p']}, B {st['b']})")
    print(f"extract files in inventory: {st['extract']}")
    print(f"distinct sources covered  : {st['covered']}")
    print(f"total entries (incl. splits): {st['entries']}")
    print(f"total chars               : {st['total_chars']:,}  (inventory extract: {st['inv_chars']:,})")
    print(f"max batch chars           : {st['max_chars']:,}  (limit {char_limit:,})")
    print(f"multi-entry sources boundary-checked: {st['boundary_checked']}")
    if errs:
        print(f"\nFAIL — {len(errs)} problem(s):")
        for e in errs[:50]:
            print("  - " + e)
        return 1
    print("\nOK: every extract file covered exactly once; no overlaps/gaps; all batches within limit.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
