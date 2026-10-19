#!/usr/bin/env python3
"""gk — Genesis Knowledge System CLI (Phase 47, Python 3 standard library only).

Run:  python3 genesis/tools/gk/gk.py <command> [args]

Every check is a thin wrapper over :mod:`core` (which holds the testable logic).
Commands that **write** require an explicit ``--out`` path (migration safety
rule): nothing writes into the repo by default.

Commands:
  inventory --out PATH              regenerate the base-tag inventory CSV
  ledger validate <batch>           schema + unique ids + lines@base + exact items present
  coverage <batch>                  % non-blank covered, gaps, skip-reason validation
  ledger query [filters]            filter units (--area/--type/--src/--fate; --json)
  fates <area>                      every unit has a fate; targets exist; wrong has a conflict
  copycheck <paths...>              12-word overlap of new docs vs all extract sources
  exact <paths...>                  path-like tokens in new docs exist in the repos at HEAD
  validate [--knowledge DIR]        the knowledge store (frontmatter/links/state/provenance/budgets/applies_to)
  build [--check] [--out DIR]       build _build/ (deterministic); --check fails if stale
  budget [--knowledge DIR]          per-doc token budget vs umbrella §7
  rules --paths <files...>          deterministic rule selection for changed files
  context <sub-spec>                resolve + schema-validate a sub-spec's context manifest
  sample --seed S --kind K --n N    reproducible reviewer samples
  next-id <LSN|STD|WA>              allocate the next rule id
  batches check                     exact-once tiling + 200K cap + boundary-safety of batches.yaml
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import core  # noqa: E402


def _resolve_code_root(cli_root: str | None, repos: list[str]) -> Path:
    cands = [cli_root, os.environ.get("GENESIS_CODE_ROOT"),
             str(Path.home() / "repo-gitlab" / "ramaswamy.u"), str(core.REPO_ROOT.parent)]
    for c in cands:
        if c and all((Path(c).expanduser() / r / ".git").exists() for r in repos):
            return Path(c).expanduser()
    raise core.GkError("could not locate a code root with all repos: " + ", ".join(repos))


def _read_docs(paths: list[str]) -> dict[str, str]:
    out = {}
    for p in paths:
        fp = Path(p)
        out[p] = fp.read_text(encoding="utf-8")
    return out


def _all_sources() -> dict[str, str]:
    inv = core.load_inventory()
    out = {}
    for path, info in inv.items():
        if info["class"] == "extract":
            txt = core.base_blob(path)
            if txt is not None:
                out[path] = txt
    return out


# --- command handlers (return process exit code) ---------------------------
def cmd_inventory(a) -> int:
    rows = core.generate_inventory_rows()
    core.write_inventory_csv(rows, Path(a.out))
    n_ex = sum(1 for r in rows if r[5] == "extract")
    n_ar = sum(1 for r in rows if r[5] == "archive-only")
    ch = sum(r[2] for r in rows if r[5] == "extract")
    ln = sum(r[3] for r in rows if r[5] == "extract")
    print(f"wrote {a.out}: {len(rows)} rows ({n_ex} extract, {n_ar} archive-only)")
    print(f"  extract chars {ch:,}  lines {ln:,}  (archive-only rows: chars/lines = 0)")
    return 0


def cmd_ledger(a) -> int:
    if a.sub == "validate":
        path = Path(a.ledger) if a.ledger else core.MIG / "ledger" / f"{a.batch}.jsonl"
        units = core.load_jsonl(path)
        errs = core.validate_ledger(units, batch_id=a.batch)
        print(f"ledger {path} — {len(units)} units")
        for e in errs:
            print("  FAIL " + e)
        print("OK" if not errs else f"\n{len(errs)} problem(s)")
        return 1 if errs else 0
    if a.sub == "query":
        units = _load_units(a)
        res = core.query_units(units, area=a.area, type=a.type, src=a.src, fate=a.fate)
        if a.json:
            for u in res:
                print(json.dumps(u))
        else:
            print(f"{'id':<16} {'type':<10} {'area':<18} {'fate':<10} src")
            for u in res:
                print(f"{u.get('id',''):<16} {u.get('type',''):<10} "
                      f"{(u.get('primary_area') or (u.get('areas') or ['?'])[0]):<18} "
                      f"{str(u.get('fate') or '-'):<10} {u.get('src','')}")
        print(f"\n{len(res)} unit(s)")
        return 0
    return 2


def _load_units(a) -> list[dict]:
    if getattr(a, "ledger", None):
        return core.load_jsonl(Path(a.ledger))
    d = Path(a.dir) if getattr(a, "dir", None) else core.MIG / "ledger"
    units: list[dict] = []
    if d.exists():
        for p in sorted(d.glob("*.jsonl")):
            units += core.load_jsonl(p)
    return units


def cmd_coverage(a) -> int:
    cov_path = Path(a.coverage) if a.coverage else core.MIG / "ledger" / f"{a.batch}.coverage.json"
    led_path = Path(a.ledger) if a.ledger else core.MIG / "ledger" / f"{a.batch}.jsonl"
    cov = json.loads(cov_path.read_text())
    unit_ids = {u["id"] for u in core.load_jsonl(led_path)} if led_path.exists() else set()
    res = core.validate_coverage(cov, unit_ids)
    print(f"coverage {cov_path}: {res['pct']}% of non-blank lines "
          f"({res['covered_nonblank']}/{res['total_nonblank']})")
    for g in res["gaps"]:
        print("  GAP " + g)
    for e in res["errs"]:
        print("  FAIL " + e)
    ok = not res["errs"] and not res["gaps"] and res["pct"] == 100.0
    print("OK" if ok else "\nincomplete/invalid coverage")
    return 0 if ok else 1


def cmd_fates(a) -> int:
    path = Path(a.ledger) if a.ledger else core.MIG / "reconciled" / f"{a.area}.jsonl"
    units = core.load_jsonl(path)
    errs = core.check_fates(units)
    print(f"fates {path} — {len(units)} units")
    for e in errs:
        print("  FAIL " + e)
    print("OK" if not errs else f"\n{len(errs)} problem(s)")
    return 1 if errs else 0


def cmd_copycheck(a) -> int:
    new_docs = _read_docs(a.paths)
    sources = _all_sources()
    res = core.copycheck(new_docs, sources, n=a.n)
    if a.json:
        print(json.dumps(res, indent=2))
    else:
        for h in res["hits"]:
            print(f"  COPY {h['doc']}:{h['doc_line']} == {h['src']}:{h['src_line']}  “{h['shingle']}”")
        for e in res["exemptions"]:
            print(f"  EXEMPT {e['doc']}:{e['line']} [{e['kind']}] {e['reason']}")
        for e in res["errors"]:
            print(f"  ERROR {e['doc']}:{e['line']} {e['msg']}")
    print(f"\n{len(res['hits'])} overlap(s) of >= {a.n} words; "
          f"{len(res['exemptions'])} exemption(s); {len(res['errors'])} error(s)")
    return 1 if (res["hits"] or res["errors"]) else 0


def cmd_exact(a) -> int:
    areas = core.load_areas()
    root = _resolve_code_root(a.code_root, areas["repos"])
    new_docs = _read_docs(a.paths)
    missing = core.exact_check(new_docs, root, areas["repos"])
    for m in missing:
        print(f"  MISSING {m['doc']}: {m['token']} — {m['reason']}")
    print("OK" if not missing else f"\n{len(missing)} missing reference(s)")
    return 1 if missing else 0


def cmd_validate(a) -> int:
    knowledge = Path(a.knowledge) if a.knowledge else core.KNOWLEDGE
    rf = None
    try:
        areas = core.load_areas()
        root = _resolve_code_root(getattr(a, "code_root", None), areas["repos"])
        rf = core.repo_files(root, areas["repos"])
    except core.GkError:
        print("note: code root not found — skipping applies_to dead-glob lint (P3)", file=sys.stderr)
    warns: list = []
    errs = core.validate_store(knowledge, repo_files=rf, warnings=warns)
    for e in errs:
        print("  FAIL " + e)
    for w in warns:
        print("  WARN " + w)
    if errs:
        print(f"\n{len(errs)} problem(s), {len(warns)} warning(s)")
    else:
        print(f"OK ({len(warns)} warning(s))" if warns else "OK")
    return 1 if errs else 0


def cmd_build(a) -> int:
    knowledge = Path(a.knowledge) if a.knowledge else core.KNOWLEDGE
    if a.check:
        out = Path(a.out) if a.out else None
        stale = core.build_check(knowledge, out)
        for s in stale:
            print("  STALE " + s)
        print("OK: _build is fresh" if not stale else f"\n{len(stale)} stale/missing built file(s)")
        return 1 if stale else 0
    if not a.out:
        print("refusing to write without --out (migration safety rule)", file=sys.stderr)
        return 2
    written = core.write_build(knowledge, Path(a.out))
    print(f"wrote {len(written)} built file(s) under {a.out}")
    return 0


def cmd_budget(a) -> int:
    knowledge = Path(a.knowledge) if a.knowledge else core.KNOWLEDGE
    rep = core.budget_report(core.build_store(knowledge))
    over = 0
    for b in rep:
        flag = "OVER" if b["over"] else "ok"
        if b["over"]:
            over += 1
        print(f"  [{flag}] {b['doc']:<40} {b['tokens']:>6} / {b['limit']} tok ({b['kind']})")
    print("OK" if not over else f"\n{over} doc(s) over budget")
    return 1 if over else 0


def cmd_rules(a) -> int:
    areas = core.load_areas()
    rules = core.load_rules(core.KNOWLEDGE / "rules")
    sel = core.rules_for_paths(a.paths, areas["areas"], rules)
    al = core.areas_for_paths(a.paths, areas["areas"])
    print("areas: " + ", ".join(al + ["all"]))
    print("rules: " + (", ".join(sel) if sel else "(none)"))
    return 0


def cmd_context(a) -> int:
    text = Path(a.subspec).read_text()
    man = core.parse_context_manifest(text)
    if man is None:
        print("no context manifest found", file=sys.stderr)
        return 1
    schema = core.load_schema("context-manifest.schema.json")
    errs = core.schema_validate(schema, {"context": man})
    print(json.dumps(man, indent=2))
    for e in errs:
        print("  INVALID " + e, file=sys.stderr)
    return 1 if errs else 0


def cmd_sample(a) -> int:
    units = inv = docs = None
    if a.kind == "ledger":
        units = _load_units(a)
    elif a.kind == "source":
        inv = core.load_inventory()
    elif a.kind == "doc":
        docs = sorted(str(p.relative_to(core.KNOWLEDGE))
                      for p in core.KNOWLEDGE.rglob("*.md")) if core.KNOWLEDGE.exists() else []
    res = core.sample(a.seed, a.kind, a.n, units=units, inventory=inv, docs=docs)
    for r in res:
        print(json.dumps(r) if not isinstance(r, str) else r)
    return 0


def cmd_nextid(a) -> int:
    print(core.next_id(a.prefix))
    return 0


def cmd_batches(a) -> int:
    if a.sub != "check":
        return 2
    inv = core.load_inventory()
    batches, limit = core.load_batches(Path(a.batches) if a.batches else None)
    errs, st = core.check_batches_all(inv, batches, limit)
    print(f"batches: {st['batches']}  (pilot {st['p']}, B {st['b']})  char_limit {limit:,}")
    print(f"extract files: {st['extract']}  distinct covered: {st['covered']}  "
          f"entries: {st['entries']}")
    print(f"total chars: {st['total_chars']:,}  (inventory extract: {st['inv_chars']:,})  "
          f"max batch: {st['max_chars']:,}")
    print(f"multi-entry sources boundary-checked: {st['boundary_checked']}")
    for e in errs:
        print("  FAIL " + e)
    print("\nOK: tiling exact-once, within cap, boundaries safe" if not errs
          else f"\n{len(errs)} problem(s)")
    return 1 if errs else 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="gk", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("inventory"); s.add_argument("--out", required=True); s.set_defaults(fn=cmd_inventory)

    s = sub.add_parser("ledger")
    lsub = s.add_subparsers(dest="sub", required=True)
    sv = lsub.add_parser("validate"); sv.add_argument("batch"); sv.add_argument("--ledger")
    sq = lsub.add_parser("query")
    for opt in ("area", "type", "src", "fate", "ledger", "dir"):
        sq.add_argument(f"--{opt}")
    sq.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_ledger)

    s = sub.add_parser("coverage"); s.add_argument("batch")
    s.add_argument("--coverage"); s.add_argument("--ledger"); s.set_defaults(fn=cmd_coverage)

    s = sub.add_parser("fates"); s.add_argument("area"); s.add_argument("--ledger")
    s.set_defaults(fn=cmd_fates)

    s = sub.add_parser("copycheck"); s.add_argument("paths", nargs="+")
    s.add_argument("--n", type=int, default=12); s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_copycheck)

    s = sub.add_parser("exact"); s.add_argument("paths", nargs="+")
    s.add_argument("--code-root", dest="code_root"); s.set_defaults(fn=cmd_exact)

    s = sub.add_parser("validate"); s.add_argument("--knowledge")
    s.add_argument("--code-root", dest="code_root"); s.set_defaults(fn=cmd_validate)

    s = sub.add_parser("build"); s.add_argument("--check", action="store_true")
    s.add_argument("--out"); s.add_argument("--knowledge"); s.set_defaults(fn=cmd_build)

    s = sub.add_parser("budget"); s.add_argument("--knowledge"); s.set_defaults(fn=cmd_budget)

    s = sub.add_parser("rules"); s.add_argument("--paths", nargs="+", required=True)
    s.set_defaults(fn=cmd_rules)

    s = sub.add_parser("context"); s.add_argument("subspec"); s.set_defaults(fn=cmd_context)

    s = sub.add_parser("sample"); s.add_argument("--seed", type=int, required=True)
    s.add_argument("--kind", required=True, choices=["source", "ledger", "doc"])
    s.add_argument("--n", type=int, default=30)
    s.add_argument("--ledger"); s.add_argument("--dir"); s.set_defaults(fn=cmd_sample)

    s = sub.add_parser("next-id"); s.add_argument("prefix", choices=["LSN", "STD", "WA"])
    s.set_defaults(fn=cmd_nextid)

    s = sub.add_parser("batches")
    bsub = s.add_subparsers(dest="sub", required=True)
    bc = bsub.add_parser("check"); bc.add_argument("--batches")
    s.set_defaults(fn=cmd_batches)
    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.fn(args)
    except core.GkError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
