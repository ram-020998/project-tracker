"""Command-line entry point. Exit codes: 0 ok, 1 findings, 2 usage/config error (47-03 §2)."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from . import __version__
from .config import CtxError, Ctx, default_repos, default_tracker


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="genesis-ctx",
        description="The Genesis context compiler (Phase 47). Deterministic, offline, stdlib-only.",
    )
    p.add_argument("--version", action="version", version=f"genesis-ctx {__version__}")
    p.add_argument("--tracker", type=Path, help="project-tracker/genesis/ (default: derived from the tool location)")
    p.add_argument("--repos", type=Path, help="repos root (default: ~/.kiro/genesis/install.json, else the built-in)")
    sub = p.add_subparsers(dest="cmd", metavar="COMMAND", required=True)

    s = sub.add_parser("status", help="repos: branch, latest tag, dirty, ahead; active phase")
    s.add_argument("--brief", action="store_true", help="≤ 25 lines (SessionStart hook)")
    s.add_argument("--json", action="store_true")

    s = sub.add_parser("pack", help="compile the context pack for a sub-spec (or --areas)")
    s.add_argument("spec", nargs="?", help="sub-spec id (48-03), umbrella id (48) or path")
    s.add_argument("--areas", help="comma-separated extra areas (alone: bug fixes / small tasks)")
    s.add_argument("--out", help="output file (default context/.packs/<id>.md)")

    s = sub.add_parser("check", help="changed files → areas → the rule checklist + gates")
    g = s.add_mutually_exclusive_group(required=True)
    g.add_argument("--since", metavar="REV")
    g.add_argument("--files", nargs="+", metavar="F")
    g.add_argument("--staged", action="store_true")
    s.add_argument("--repo", help="limit to one repo (genesis, genesis-core, …)")
    s.add_argument("--json", action="store_true")

    s = sub.add_parser("adr", help="full text of ADR(s) + bible/04 bullets + amendment chain")
    s.add_argument("ids", nargs="+")
    s.add_argument("--no-chain", action="store_true")

    s = sub.add_parser("lesson", help="lesson bullet(s) verbatim")
    s.add_argument("ids", nargs="+")

    s = sub.add_parser("area", help="an area: catalog line, rules, code-map sections, docs, skills")
    s.add_argument("name")

    s = sub.add_parser("search", help="regex over the active layer (history with --archive)")
    s.add_argument("pattern")
    s.add_argument("--archive", action="store_true", help="also archive/, specs/, progress/")
    s.add_argument("--max", type=int, default=50)
    s.add_argument("--case", action="store_true", help="case-sensitive")

    s = sub.add_parser("index", help="regenerate context/_generated/*; fill empty reviewed_fp")
    s.add_argument("--reviewed", nargs="+", metavar="ID", help="refresh reviewed_fp for these (rules reviewed)")
    s.add_argument("--reviewed-all", action="store_true")

    s = sub.add_parser("lint", help="validate the context layer (47-03 §5)")
    s.add_argument("--quiet", action="store_true")
    s.add_argument("--specs-only", action="store_true")
    s.add_argument("--json", action="store_true")

    s = sub.add_parser("add", help="scaffold a new ADR or lesson + its tag entry, then index")
    asub = s.add_subparsers(dest="what", required=True)
    a = asub.add_parser("adr")
    a.add_argument("--id", required=True)
    a.add_argument("--title", required=True)
    a.add_argument("--areas", required=True)
    a.add_argument("--rule", required=True)
    a.add_argument("--body-file")
    a.add_argument("--amends", nargs="+", metavar="ADR")
    a.add_argument("--status", default="proposed", choices=["proposed", "accepted"])
    a = asub.add_parser("lesson")
    a.add_argument("--areas", required=True)
    a.add_argument("--rule", required=True)
    a.add_argument("--body-file")
    a.add_argument("--phase", default="")

    s = sub.add_parser("mark", help="one-shot: insert <!-- L-NNN --> markers into bible/06 §7 (idempotent)")
    s.add_argument("--dry-run", action="store_true")

    s = sub.add_parser("archive", help="one-shot: move plan ranges into archive/ (dry run by default)")
    s.add_argument("--plan", required=True)
    s.add_argument("--step", type=int)
    s.add_argument("--apply", action="store_true")

    s = sub.add_parser("propose-tags", help="one-shot: write context/tags/*.proposed.toml (47-05 input)")
    s.add_argument("--out-dir", help="write elsewhere (e.g. a temp dir for a preview)")

    s = sub.add_parser("propose-b04", help="one-shot: flag each bible/04 bullet include/skip for pack dedupe")
    s.add_argument("--apply", action="store_true", help="write `b04` into tags/adr.toml (dry-run by default)")

    s = sub.add_parser("verify-lossless", help="prove no baseline paragraph is missing (47-03 §6)")
    s.add_argument("--baseline", required=True, metavar="REV")
    s.add_argument("--write", action="store_true", help="store archive/LOSSLESS.json")
    s.add_argument("--max-dups", type=int, default=30)
    return p


def run(args: argparse.Namespace) -> int:
    ctx = Ctx(tracker=(args.tracker or default_tracker()).resolve(), repos=(args.repos or default_repos()))
    if not ctx.tracker.is_dir():
        raise CtxError(f"tracker not found: {ctx.tracker}")
    if args.cmd == "status":
        from .query import cmd_status
        return cmd_status(ctx, args.brief, args.json)
    if args.cmd == "pack":
        from .pack import cmd_pack
        return cmd_pack(ctx, args.spec, args.areas, args.out)
    if args.cmd == "check":
        from .pack import cmd_check
        return cmd_check(ctx, args.since, args.files, args.staged, args.repo, args.json)
    if args.cmd == "adr":
        from .query import cmd_adr
        return cmd_adr(ctx, args.ids, not args.no_chain)
    if args.cmd == "lesson":
        from .query import cmd_lesson
        return cmd_lesson(ctx, args.ids)
    if args.cmd == "area":
        from .query import cmd_area
        return cmd_area(ctx, args.name)
    if args.cmd == "search":
        from .query import cmd_search
        return cmd_search(ctx, args.pattern, args.archive, args.max, args.case)
    if args.cmd == "index":
        from .index import cmd_index
        return cmd_index(ctx, args.reviewed, args.reviewed_all)
    if args.cmd == "lint":
        from .lint import cmd_lint
        return cmd_lint(ctx, args.quiet, args.specs_only, args.json)
    if args.cmd == "add":
        from .add import cmd_add_adr, cmd_add_lesson
        if args.what == "adr":
            return cmd_add_adr(ctx, args.id, args.title, args.areas, args.rule, args.body_file, args.amends,
                               args.status)
        return cmd_add_lesson(ctx, args.areas, args.rule, args.body_file, args.phase)
    if args.cmd == "mark":
        from .migrate import cmd_mark
        return cmd_mark(ctx, args.dry_run)
    if args.cmd == "archive":
        from .migrate import cmd_archive
        return cmd_archive(ctx, args.plan, args.step, args.apply)
    if args.cmd == "propose-tags":
        from .migrate import cmd_propose_tags
        return cmd_propose_tags(ctx, args.out_dir)
    if args.cmd == "propose-b04":
        from .migrate import cmd_propose_b04
        return cmd_propose_b04(ctx, args.apply)
    if args.cmd == "verify-lossless":
        from .migrate import cmd_verify_lossless
        return cmd_verify_lossless(ctx, args.baseline, args.write, args.max_dups)
    raise CtxError(f"unknown command {args.cmd}")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as e:  # argparse: 0 for --help/--version, 2 for usage errors
        return int(e.code or 0)
    try:
        return run(args)
    except CtxError as e:
        print(f"genesis-ctx: error: {e}", file=sys.stderr)
        return 2
    except BrokenPipeError:
        return 0
