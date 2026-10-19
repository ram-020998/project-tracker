"""gk core — Phase 47 Genesis Knowledge System tooling (Python 3 standard library only).

Every migration check the method relies on lives here as a **pure, testable
function**. ``gk.py`` is a thin CLI over these. No third-party dependency
(PyYAML is absent in the target env — all YAML here is hand-parsed for the small
subset the migration files use).

Conventions
-----------
* Sources are read **at the migration base tag** (``git show <tag>:<path>``),
  never the working tree (47-01 review P3) — see :func:`base_blob`.
* ``splitlines()`` is the 1-based line convention the extractor sees.
* Char counts are Unicode code points; token budget = ``ceil(chars / 4)``.
"""
from __future__ import annotations

import csv
import json
import math
import re
import subprocess
from pathlib import Path

# --- paths & constants -----------------------------------------------------
# core.py is genesis/tools/gk/core.py  ->  parents[3] = repo root.
REPO_ROOT = Path(__file__).resolve().parents[3]
GENESIS = REPO_ROOT / "genesis"
MIG = GENESIS / "migration"
SCHEMA_DIR = MIG / "schemas"
KNOWLEDGE = GENESIS / "knowledge"
BASE_TAG = "knowledge-migration-base"

AREA_IDS = [
    "engine", "runs-config", "data-plane", "workflow-library", "agent-sdk",
    "chat-copilot", "appian-kb", "appian-parser", "feature-sdlc",
    "stories-workbench", "collaboration-hub", "memory", "web-ui", "dev-release-ops",
]
PSEUDO_AREAS = ["all", "history"]
ALL_AREAS = AREA_IDS + PSEUDO_AREAS

# Token budgets (umbrella §7), in tokens (chars/4).
BUDGETS = {"core": 15000, "pack": 12000, "reference": 8000, "rule": 1500, "procedure": 12000}

# State facts may live ONLY in knowledge/state/ (gk validate). Patterns that
# --- state-fact catalogue (gk validate) ------------------------------------
# A "state fact" is a value that CHANGES PER RELEASE and must therefore live only
# in knowledge/state/current.yaml — never restated in a pack / core / reference /
# procedure doc. ``gk validate`` scans those prose docs after stripping code
# spans/fences (:func:`_strip_code_only`) AND URLs (:func:`_strip_urls`), and
# never scans ``state/``.
#
# DETECTED (flagged when it appears in prose outside state/):
#   - version string, with or without a leading v ...... v0.69.0 / 0.69.0
#   - the current_version / db_current_version key ..... db_current_version
#   - migration id ..................................... m0024
#   - DB/schema version written in prose ............... DB v24 / version 20
#   - test count next to a runner word, or "<n> tests" . pytest 1105 / vitest 332 / jest 332 / 99 tests
#   - CI pipeline/job/run id (hyphen, space or #) ...... gl-9931 / CI 7087827 / pipeline #45678 / job 7087827
#   - a bare 6+-digit ref after # ...................... #7087827
#
# ALLOWED (never flagged): anything in knowledge/state/; identifiers inside a
#   `code` span or fence; a version inside a URL or markdown-link target (the link
#   TEXT is still scanned); a short #ref such as #12; an HTTP status like HTTP 409;
#   two-part numbers that are not semver (section 3.2, Python 3.11); plain counts
#   not next to a test-runner word (step 13).
#
# Detection is HEURISTIC: this catalogue is what the mechanical check guarantees;
# near-miss forms outside it are deferred to the §6.2 human review (see the
# "Deferred checks" note in PROGRESS and review-2 F2).
STATE_FACT_PATTERNS = [
    (re.compile(r"\bv?\d+\.\d+\.\d+\b"), "version string"),
    (re.compile(r"current_version"), "current_version key"),
    (re.compile(r"\bm0\d{3}\b"), "migration id"),
    (re.compile(r"\bDB\s+v?\d+\b", re.I), "DB version"),
    (re.compile(r"\bversion\s+\d+\b", re.I), "version number"),
    (re.compile(r"\b\d+\s+tests?\b", re.I), "test count"),
    (re.compile(r"\b(?:pytest|vitest|jest|mocha|unittest|go\s+test)\s+\d+\b", re.I), "test count"),
    (re.compile(r"\b(?:gl|ci|job|run|pipeline)[-\s]#?\d+\b", re.I), "CI id"),
    (re.compile(r"#\d{6,}\b"), "CI id"),
]

PROVENANCE_RE = re.compile(r"<!--\s*src:\s*[^>]*-->")
VERBATIM_RE = re.compile(r"<!--\s*verbatim:(?P<reason>[^>]*)-->")
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
FENCE_RE = re.compile(r"^\s*```")
INLINE_CODE_RE = re.compile(r"`[^`]*`")
MD_LINK_RE = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)]+)\)")


class GkError(Exception):
    """A usage/environment error (missing file, bad tag)."""


# --- git / blobs -----------------------------------------------------------
def _git(*args: str, repo: Path = REPO_ROOT) -> str:
    return subprocess.run(["git", "-C", str(repo), *args],
                          check=True, capture_output=True, text=True).stdout


_blob_cache: dict[str, str | None] = {}


def base_blob(path: str) -> str | None:
    """Text of ``path`` at the base tag, or None if it does not exist there."""
    if path in _blob_cache:
        return _blob_cache[path]
    try:
        text = _git("show", f"{BASE_TAG}:{path}")
    except subprocess.CalledProcessError:
        text = None
    _blob_cache[path] = text
    return text


def base_lines(path: str) -> list[str]:
    text = base_blob(path)
    if text is None:
        raise GkError(f"{path} not found at {BASE_TAG}")
    return text.splitlines()


# --- minimal JSON-schema subset validator (shared with validate_schemas) ---
_TYPE_PY = {"object": dict, "array": list, "string": str, "integer": int,
            "number": (int, float), "boolean": bool, "null": type(None)}


def schema_check(schema: dict, value, path: str, errs: list[str]) -> None:
    if value is None and schema.get("nullable"):
        return
    t = schema.get("type")
    if t:
        if t in ("integer", "number") and isinstance(value, bool):
            errs.append(f"{path}: expected {t}, got boolean"); return
        if not isinstance(value, _TYPE_PY[t]):
            errs.append(f"{path}: expected {t}, got {type(value).__name__}"); return
    if "const" in schema and value != schema["const"]:
        errs.append(f"{path}: expected const {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errs.append(f"{path}: {value!r} not in enum")
    if "pattern" in schema and isinstance(value, str) and not re.fullmatch(schema["pattern"], value):
        errs.append(f"{path}: {value!r} !~ /{schema['pattern']}/")
    if t == "object" and isinstance(value, dict):
        for req in schema.get("required", []):
            if req not in value:
                errs.append(f"{path}: missing required key '{req}'")
        for group in schema.get("x-exactly-one-of", []):
            present = [k for k in group if k in value]
            if len(present) != 1:
                errs.append(f"{path}: exactly one of {group} required, found {present}")
        for rule in schema.get("x-required-if", []):
            if value.get(rule["property"]) == rule["const"]:
                for req in rule["required"]:
                    if req not in value:
                        errs.append(f"{path}: '{req}' required when {rule['property']}={rule['const']!r}")
        for k, sub in schema.get("properties", {}).items():
            if k in value:
                schema_check(sub, value[k], f"{path}.{k}", errs)
    if t == "array" and isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            errs.append(f"{path}: needs >= {schema['minItems']} items")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errs.append(f"{path}: needs <= {schema['maxItems']} items")
        if schema.get("items"):
            for i, item in enumerate(value):
                schema_check(schema["items"], item, f"{path}[{i}]", errs)


def schema_validate(schema: dict, value) -> list[str]:
    errs: list[str] = []
    schema_check(schema, value, "$", errs)
    return errs


def load_schema(name: str) -> dict:
    return json.loads((SCHEMA_DIR / name).read_text())


# --- areas.yaml / batches.yaml hand-parsers --------------------------------
def glob_to_regex(glob: str) -> re.Pattern:
    """gitignore-like glob -> anchored regex (segment * , crossing ** , trailing /**)."""
    segs = glob.split("/")
    out = ["^"]
    for i, seg in enumerate(segs):
        if seg == "**":
            out.append("(?:[^/]+/)*")
            if i == len(segs) - 1:
                out.append("[^/]*")
            continue
        part = []
        for ch in seg:
            part.append("[^/]*" if ch == "*" else "[^/]" if ch == "?" else re.escape(ch))
        out.append("".join(part))
        if i != len(segs) - 1:
            out.append("/")
    pattern = "".join(out).replace("/(?:[^/]+/)*[^/]*$", "(?:/.*)?$")
    if not pattern.endswith("$"):
        pattern += "$"
    return re.compile(pattern)


def load_areas(areas_yaml: Path | None = None) -> dict:
    """Parse areas.yaml -> {areas:[{id,code:[globs]}], exceptions:[{glob}], repos:[...]}."""
    p = areas_yaml or (MIG / "areas.yaml")
    areas: list[dict] = []
    exceptions: list[dict] = []
    repos: list[str] = []
    section = None
    cur = None
    in_code = in_repos = False
    for raw in p.read_text().splitlines():
        line = raw.rstrip("\n")
        if re.match(r"^repos:\s*$", line):
            section, in_repos = "repos", True; continue
        if re.match(r"^areas:\s*$", line):
            section, in_repos = "areas", False; continue
        if re.match(r"^pseudo_areas:\s*$", line):
            section = "pseudo"
            if cur:
                areas.append(cur); cur = None
            in_code = False; continue
        if re.match(r"^exceptions:\s*$", line):
            section = "exceptions"
            if cur:
                areas.append(cur); cur = None
            in_code = False; continue
        if section == "repos" and in_repos:
            m = re.match(r"^\s*-\s*([A-Za-z0-9_.-]+)", line)
            if m:
                repos.append(m.group(1))
            continue
        if section == "areas":
            m = re.match(r"^\s{2}-\s*id:\s*(\S+)", line)
            if m:
                if cur:
                    areas.append(cur)
                cur = {"id": m.group(1), "code": []}; in_code = False; continue
            if re.match(r"^\s{4}code:\s*$", line):
                in_code = True; continue
            if in_code:
                m2 = re.match(r"^\s{6}-\s*(\S+)", line)
                if m2:
                    cur["code"].append(m2.group(1)); continue
                if re.match(r"^\s{4}\w", line):
                    in_code = False
        if section == "exceptions":
            m = re.match(r"^\s{2}-\s*glob:\s*(\S+)", line)
            if m:
                exceptions.append({"glob": m.group(1)})
    if cur and section == "areas":
        areas.append(cur)
    return {"areas": areas, "exceptions": exceptions, "repos": repos}


def load_batches(batches_yaml: Path | None = None) -> tuple[list[dict], int]:
    """Parse batches.yaml -> ([{id, chars, entries:[(src,a,b,chars)]}], char_limit)."""
    p = batches_yaml or (MIG / "batches.yaml")
    char_limit = 200_000
    batches: list[dict] = []
    cur = None
    entry_re = re.compile(
        r'^\s*-\s*\{src:\s*"(?P<src>[^"]+)",\s*lines:\s*\[(?P<a>\d+),\s*(?P<b>\d+)\],\s*chars:\s*(?P<ch>\d+)\}\s*$')
    for raw in p.read_text().splitlines():
        m = re.match(r"^char_limit:\s*(\d+)", raw)
        if m:
            char_limit = int(m.group(1)); continue
        m = re.match(r"^\s{2}-\s*id:\s*(\S+)", raw)
        if m:
            if cur:
                batches.append(cur)
            cur = {"id": m.group(1), "chars": None, "entries": []}; continue
        m = re.match(r"^\s{4}chars:\s*(\d+)", raw)
        if m and cur:
            cur["chars"] = int(m.group(1)); continue
        m = entry_re.match(raw)
        if m and cur:
            cur["entries"].append((m["src"], int(m["a"]), int(m["b"]), int(m["ch"])))
    if cur:
        batches.append(cur)
    return batches, char_limit


# --- inventory (M4 + P3) ---------------------------------------------------
TYPE_BY_EXT = {".md": "markdown", ".markdown": "markdown", ".json": "json",
               ".yaml": "yaml", ".yml": "yaml", ".py": "python", ".js": "javascript",
               ".ts": "typescript", ".html": "html", ".htm": "html", ".csv": "csv",
               ".txt": "text", ".toml": "toml", ".cfg": "config", ".ini": "config",
               ".canvas": "json", ".gz": "archive", ".tgz": "archive", ".zip": "archive",
               ".tar": "archive", ".png": "image", ".jpg": "image", ".jpeg": "image",
               ".gif": "image", ".svg": "image", ".pdf": "pdf", ".ico": "image",
               ".woff": "font", ".woff2": "font", ".ttf": "font"}
ARCHIVE_EXT_REASON = {
    ".gz": "compressed binary bundle; no extractable prose",
    ".tgz": "compressed binary bundle; no extractable prose",
    ".tar": "binary archive; no extractable prose",
    ".zip": "compressed binary archive; no extractable prose",
    ".png": "binary image; no extractable text", ".jpg": "binary image; no extractable text",
    ".jpeg": "binary image; no extractable text", ".gif": "binary image; no extractable text",
    ".ico": "binary icon; no extractable text", ".pdf": "binary PDF; no extractable text",
    ".woff": "binary font; no extractable text", ".woff2": "binary font; no extractable text",
    ".ttf": "binary font; no extractable text"}


def classify(rel_path: str, is_text: bool) -> tuple[str, str, str]:
    """(type, class, reason). Pure: decided from path + whether it decoded as UTF-8."""
    p = Path(rel_path)
    ext = p.suffix.lower()
    ftype = TYPE_BY_EXT.get(ext, "text")
    if p.name == ".DS_Store":
        return "os-metadata", "archive-only", "macOS Finder metadata; no knowledge content"
    if "/.obsidian/" in f"/{rel_path}":
        return "json", "archive-only", "Obsidian editor workspace/config; no knowledge content"
    if ext in ARCHIVE_EXT_REASON:
        return ftype, "archive-only", ARCHIVE_EXT_REASON[ext]
    if not is_text:
        return (ftype if ftype != "text" else "binary"), "archive-only", "binary (non-UTF-8); no extractable text"
    return ftype, "extract", ""


def build_inventory(files_with_blobs: list[tuple[str, bytes | None]]) -> list[list]:
    """Rows [path,bytes,chars,lines,type,class,reason] from (path, raw-bytes-at-base).

    M4 convention: **every archive-only row records chars=0, lines=0** (a single
    consistent convention for text and binary archive-only files alike); only
    ``extract`` rows carry real char/line counts.
    """
    rows = []
    for rel, data in files_with_blobs:
        if data is None:
            rows.append([rel, 0, 0, 0, "missing", "archive-only", "not present at base tag"]); continue
        try:
            text = data.decode("utf-8")
            is_text = True
        except UnicodeDecodeError:
            text, is_text = None, False
        ftype, klass, reason = classify(rel, is_text)
        if klass == "archive-only":
            nchars = nlines = 0            # M4: consistent zero for all archive-only
        else:
            nchars, nlines = len(text), len(text.splitlines())
        rows.append([rel, len(data), nchars, nlines, ftype, klass, reason])
    return rows


def git_tracked_sources() -> list[str]:
    """Tracked files under genesis/ at the base tag, excluding the migration workspace."""
    out = _git("ls-tree", "-r", "--name-only", BASE_TAG, "--", "genesis/")
    return [f for f in out.splitlines() if f and not f.startswith("genesis/migration/")]


def generate_inventory_rows() -> list[list]:
    files = git_tracked_sources()
    pairs: list[tuple[str, bytes | None]] = []
    for rel in files:
        try:
            raw = subprocess.run(["git", "-C", str(REPO_ROOT), "show", f"{BASE_TAG}:{rel}"],
                                 check=True, capture_output=True).stdout
        except subprocess.CalledProcessError:
            raw = None
        pairs.append((rel, raw))
    return build_inventory(pairs)


def write_inventory_csv(rows: list[list], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["path", "bytes", "chars", "lines", "type", "class", "reason"])
        w.writerows(rows)


def load_inventory(path: Path | None = None) -> dict[str, dict]:
    p = path or (MIG / "inventory.csv")
    out = {}
    with p.open() as fh:
        for row in csv.DictReader(fh):
            out[row["path"]] = {"chars": int(row["chars"]), "lines": int(row["lines"]),
                                "class": row["class"]}
    return out


# --- ledger & coverage -----------------------------------------------------
def load_jsonl(path: Path) -> list[dict]:
    units = []
    for i, raw in enumerate(path.read_text().splitlines(), 1):
        raw = raw.strip()
        if not raw:
            continue
        try:
            units.append(json.loads(raw))
        except json.JSONDecodeError as e:
            raise GkError(f"{path}:{i}: invalid JSON: {e}")
    return units


def validate_ledger(units: list[dict], blob_lines=base_lines, batch_id: str | None = None) -> list[str]:
    """Schema, unique ids, lines within the base-tag file, exact items literally present."""
    schema = load_schema("knowledge-unit.schema.json")
    errs: list[str] = []
    seen: set[str] = set()
    for u in units:
        uid = u.get("id", "<no-id>")
        for e in schema_validate(schema, u):
            errs.append(f"{uid}: schema: {e}")
        if uid in seen:
            errs.append(f"{uid}: duplicate id")
        seen.add(uid)
        if batch_id and isinstance(u.get("id"), str) and not u["id"].startswith(f"KU-{batch_id}-"):
            errs.append(f"{uid}: id does not belong to batch {batch_id}")
        src, lines = u.get("src"), u.get("lines")
        if not (isinstance(lines, list) and len(lines) == 2):
            continue
        a, b = lines
        if a < 1 or b < a:
            errs.append(f"{uid}: bad line range {lines}"); continue
        try:
            file_lines = blob_lines(src)
        except GkError as e:
            errs.append(f"{uid}: {e}"); continue
        if b > len(file_lines):
            errs.append(f"{uid}: lines {lines} exceed {src} ({len(file_lines)} lines at base)")
            continue
        span = "\n".join(file_lines[a - 1:b])
        for item in u.get("exact", []):
            if item not in span:
                errs.append(f"{uid}: exact item {item!r} not found literally in {src}:{a}-{b}")
    return errs


def _nonblank(line: str) -> bool:
    return line.strip() != ""


def _is_heading(ln: str) -> bool:
    return bool(re.match(r"\s{0,3}#{1,6}\s", ln))


def _has_words(ln: str) -> bool:
    # a "word" = a run of letters (so pure punctuation/table rules have none).
    return bool(re.search(r"[A-Za-z]{2,}", ln))


def validate_coverage(cov: dict, batch_unit_ids: set[str], blob_lines=base_lines) -> dict:
    """Validate a batch coverage map. Returns {pct, gaps, errs}.

    * every skip reason is justified: ``blank`` lines are blank; ``heading-only``
      lines are headings; ``formatting`` lines carry no words; ``duplicate``
      points (via ``duplicate_of``) to a unit present in the batch;
    * ``pct`` = covered non-blank lines / total non-blank lines over the sources
      named in the map; ``gaps`` lists uncovered non-blank ranges.
    """
    errs: list[str] = []
    schema = load_schema("coverage.schema.json")
    for e in schema_validate(schema, cov):
        errs.append(f"schema: {e}")
    by_src: dict[str, list] = {}
    for entry in cov.get("coverage", []):
        by_src.setdefault(entry["src"], []).append(entry)

    total_nb = covered_nb = 0
    gaps: list[str] = []
    for src, entries in by_src.items():
        try:
            lines = blob_lines(src)
        except GkError as e:
            errs.append(str(e)); continue
        covered = [False] * (len(lines) + 1)
        for entry in entries:
            a, b = entry["lines"]
            if a < 1 or b > len(lines) or b < a:
                errs.append(f"{src}: range {entry['lines']} out of bounds"); continue
            for i in range(a, b + 1):
                covered[i] = True
            skip = entry.get("skip")
            if skip == "blank":
                bad = [i for i in range(a, b + 1) if _nonblank(lines[i - 1])]
                if bad:
                    errs.append(f"{src}:{a}-{b}: skip=blank but lines {bad[:5]} are non-blank")
            elif skip == "heading-only":
                bad = [i for i in range(a, b + 1) if _nonblank(lines[i - 1]) and not _is_heading(lines[i - 1])]
                if bad:
                    errs.append(f"{src}:{a}-{b}: skip=heading-only but lines {bad[:5]} are not headings")
            elif skip == "formatting":
                bad = [i for i in range(a, b + 1) if _has_words(lines[i - 1])]
                if bad:
                    errs.append(f"{src}:{a}-{b}: skip=formatting but lines {bad[:5]} contain words")
            elif skip == "duplicate":
                tgt = entry.get("duplicate_of")
                if not tgt:
                    errs.append(f"{src}:{a}-{b}: skip=duplicate without duplicate_of")
                elif tgt not in batch_unit_ids:
                    errs.append(f"{src}:{a}-{b}: duplicate_of {tgt} not a unit in this batch")
            elif "units" in entry:
                for uid in entry["units"]:
                    if uid not in batch_unit_ids:
                        errs.append(f"{src}:{a}-{b}: cites unknown unit {uid}")
        # coverage stats + gaps over non-blank lines
        run_start = None
        for i in range(1, len(lines) + 1):
            nb = _nonblank(lines[i - 1])
            if nb:
                total_nb += 1
                if covered[i]:
                    covered_nb += 1
            uncovered_nb = nb and not covered[i]
            if uncovered_nb and run_start is None:
                run_start = i
            elif not uncovered_nb and run_start is not None:
                gaps.append(f"{src}:{run_start}-{i-1}"); run_start = None
        if run_start is not None:
            gaps.append(f"{src}:{run_start}-{len(lines)}")

    pct = 100.0 if total_nb == 0 else round(100.0 * covered_nb / total_nb, 2)
    return {"pct": pct, "gaps": gaps, "errs": errs, "total_nonblank": total_nb,
            "covered_nonblank": covered_nb}


# --- query / fates ---------------------------------------------------------
def query_units(units: list[dict], area=None, type=None, src=None, fate=None) -> list[dict]:
    out = []
    for u in units:
        if area and area not in u.get("areas", []):
            continue
        if type and u.get("type") != type:
            continue
        if src and u.get("src") != src:
            continue
        if fate and u.get("fate") != fate:
            continue
        out.append(u)
    return out


CONFLICT_RE = re.compile(r"conflicts(?:\.md)?#\S+")


def check_fates(units: list[dict]) -> list[str]:
    """Every unit has a fate; merge/supersede targets exist; wrong has a conflict id;
    and **every merge/supersede chain terminates at a surviving unit** (no cycle,
    no chain that strands the knowledge).

    * a ``merge`` chain must end at a unit whose fate is ``keep``;
    * a ``superseded`` chain must end at ``keep``, ``history`` or a rule id
      (ADR/LSN/STD/WA — a surviving rule);
    * a cycle in the merge/supersede graph is reported with the whole chain.
    """
    errs: list[str] = []
    by_id = {u.get("id"): u for u in units}
    ids = set(by_id)
    for u in units:
        uid = u.get("id", "<no-id>")
        fate = u.get("fate")
        if not fate:
            errs.append(f"{uid}: no fate set"); continue
        tgt = u.get("fate_target")
        if fate == "merge":
            if not tgt:
                errs.append(f"{uid}: fate=merge without fate_target")
            elif tgt not in ids:
                errs.append(f"{uid}: merge target {tgt} not present")
        elif fate == "superseded":
            if not tgt:
                errs.append(f"{uid}: fate=superseded without fate_target")
            elif not (tgt in ids or re.fullmatch(r"(ADR|LSN|STD|WA)-\d{3}", tgt)):
                errs.append(f"{uid}: supersede target {tgt} is neither a KU in scope nor a rule id")
        elif fate == "wrong":
            ref = tgt or ""
            notes = u.get("notes") or ""
            if not (CONFLICT_RE.search(ref) or CONFLICT_RE.search(notes)):
                errs.append(f"{uid}: fate=wrong without a conflict id (conflicts.md#<anchor>)")

    # Walk each merge/supersede chain to its terminal; report cycles and strands.
    rule_re = re.compile(r"(ADR|LSN|STD|WA)-\d{3}")
    for u in units:
        if u.get("fate") not in ("merge", "superseded"):
            continue
        start = u.get("id")
        seen: list[str] = [start]
        cur = u
        while True:
            tgt = cur.get("fate_target")
            if not tgt or (tgt not in by_id and rule_re.fullmatch(tgt or "")):
                # terminal is a surviving rule id (valid only for superseded);
                # a merge that points at a rule id is flagged by existence check above.
                break
            if tgt not in by_id:
                break  # missing target already reported
            if tgt in seen:
                errs.append(f"{start}: {u['fate']} chain forms a cycle: " + " -> ".join(seen + [tgt]))
                break
            seen.append(tgt)
            nxt = by_id[tgt]
            nfate = nxt.get("fate")
            if nfate not in ("merge", "superseded"):
                # terminal node reached — check it is a survivor for this chain kind
                survivors = ("keep",) if u["fate"] == "merge" else ("keep", "history")
                if nfate not in survivors:
                    errs.append(f"{start}: {u['fate']} chain ends at {tgt} (fate={nfate}), "
                                f"not a surviving unit: " + " -> ".join(seen))
                break
            cur = nxt
    return errs


# --- copy check (§6.2) -----------------------------------------------------
def _words_with_lines(text: str) -> list[tuple[str, int]]:
    out = []
    for lineno, ln in enumerate(text.splitlines(), 1):
        for m in re.finditer(r"[A-Za-z0-9]+", ln.lower()):
            out.append((m.group(0), lineno))
    return out


def _strip_noncopy(text: str) -> str:
    """Source-side strip: drop fenced code, inline code, comments, verbatim paras."""
    paras = re.split(r"\n\s*\n", text)
    paras = [p for p in paras if not VERBATIM_RE.search(p)]
    text = "\n\n".join(paras)
    out_lines, in_fence = [], False
    for ln in text.splitlines():
        if FENCE_RE.match(ln):
            in_fence = not in_fence
            continue
        if not in_fence:
            out_lines.append(ln)
    text = "\n".join(out_lines)
    text = HTML_COMMENT_RE.sub(" ", text)
    text = INLINE_CODE_RE.sub(" ", text)
    return text


def _scan_doc(text: str) -> tuple[list[tuple[str, int]], list[dict], list[dict]]:
    """New-doc scan: returns (words-with-lines, exemptions, errors).

    * a ``<!-- verbatim: reason -->`` paragraph is exempt **only** when ``reason``
      is non-empty — it is recorded as an exemption and dropped from the scan;
      an **empty** reason is an error and the paragraph is **not** exempted
      (so copied prose inside it is still caught, §6.2);
    * fenced code blocks are recorded as exemptions and dropped;
    * inline code and html comments are stripped before shingling.
    """
    lines = text.split("\n")
    n = len(lines)
    exempt = [False] * (n + 1)
    exemptions: list[dict] = []
    errors: list[dict] = []
    # 1) verbatim paragraphs (maximal runs of non-blank lines)
    j = 0
    while j < n:
        if lines[j].strip() == "":
            j += 1; continue
        k = j
        while k < n and lines[k].strip() != "":
            k += 1
        block = "\n".join(lines[j:k])
        m = VERBATIM_RE.search(block)
        if m:
            reason = m.group("reason").strip()
            if not reason:
                errors.append({"line": j + 1, "msg": "empty verbatim reason (needs a reason, §6.2)"})
            elif "<!--" in reason or "verbatim:" in reason:
                errors.append({"line": j + 1, "msg": "malformed/nested verbatim marker in reason"})
            else:
                exemptions.append({"line": j + 1, "kind": "verbatim", "reason": reason})
                for t in range(j, k):
                    exempt[t + 1] = True
        j = k
    # 2) fenced code blocks
    in_fence, fstart = False, None
    for idx in range(1, n + 1):
        if FENCE_RE.match(lines[idx - 1]):
            exempt[idx] = True
            if not in_fence:
                in_fence, fstart = True, idx
            else:
                in_fence = False
                exemptions.append({"line": fstart, "kind": "code-fence", "reason": "fenced code block"})
            continue
        if in_fence:
            exempt[idx] = True
    # 3) words (original line numbers), skipping exempt lines + inline code/comments
    words: list[tuple[str, int]] = []
    for idx in range(1, n + 1):
        if exempt[idx]:
            continue
        ln = INLINE_CODE_RE.sub(" ", HTML_COMMENT_RE.sub(" ", lines[idx - 1]))
        for mm in re.finditer(r"[A-Za-z0-9]+", ln.lower()):
            words.append((mm.group(0), idx))
    return words, exemptions, errors


def _shingle_words(words: list[tuple[str, int]], n: int) -> list[tuple[str, int]]:
    return [(" ".join(w for w, _ in words[i:i + n]), words[i][1])
            for i in range(len(words) - n + 1)]


def shingles(text: str, n: int = 12) -> list[tuple[str, int]]:
    return _shingle_words(_words_with_lines(_strip_noncopy(text)), n)


def copycheck(new_docs: dict[str, str], sources: dict[str, str], n: int = 12) -> dict:
    """12-word shingle overlap of each new doc against every source.

    Returns ``{"hits": [...], "exemptions": [...], "errors": [...]}``:
    * **hits** — ``{doc, doc_line, src, src_line, shingle}`` for each ≥ n-word run
      shared with a source (code spans, exempted verbatim blocks and fenced code
      are not scanned);
    * **exemptions** — every block skipped, with ``{doc, line, kind, reason}`` so a
      §6.2 reviewer can inspect each one (P2);
    * **errors** — e.g. an empty-reason verbatim block (M3); a non-empty ``errors``
      list fails the check.
    """
    index: dict[str, tuple[str, int]] = {}
    for spath, stext in sources.items():
        for key, line in shingles(stext, n):
            index.setdefault(key, (spath, line))
    hits, exemptions, errors = [], [], []
    for dpath, dtext in new_docs.items():
        words, ex, er = _scan_doc(dtext)
        for e in ex:
            exemptions.append({"doc": dpath, **e})
        for e in er:
            errors.append({"doc": dpath, **e})
        for key, dline in _shingle_words(words, n):
            if key in index:
                spath, sline = index[key]
                hits.append({"doc": dpath, "doc_line": dline, "src": spath,
                             "src_line": sline, "shingle": key})
    return {"hits": hits, "exemptions": exemptions, "errors": errors}


# --- exact-item existence (paths/migrations) -------------------------------
def _candidate_tokens(text: str) -> list[str]:
    """Backticked spans from a new doc (where authors keep paths/ids verbatim)."""
    toks = []
    stripped = HTML_COMMENT_RE.sub(" ", text)
    for m in re.finditer(r"`([^`]+)`", stripped):
        toks.append(m.group(1).strip())
    return toks


def exact_check(new_docs: dict[str, str], code_root: Path, repos: list[str]) -> list[dict]:
    """Path-like backticked tokens in new docs must exist in the repos at HEAD.

    A token is path-like if it contains '/' and no '://'. Repo-prefixed tokens
    (``<repo>/...``) resolve under ``code_root``; ``genesis/...`` tokens resolve
    under project-tracker. Globs (``*``) must match at least one file. Returns a
    list of ``{doc, token, reason}`` for tokens that do not exist. Non-path
    tokens (bare symbols/commands) are not resolved here (documented scope).
    """
    repo_set = set(repos)
    missing = []
    for dpath, dtext in new_docs.items():
        for tok in _candidate_tokens(dtext):
            t = tok.rstrip(".,;:)")
            if "/" not in t or "://" in t or t.startswith("http"):
                continue
            first = t.split("/", 1)[0]
            if first in repo_set:
                base = code_root / first
                rel = t.split("/", 1)[1]
            elif first == "genesis":
                base = REPO_ROOT / "genesis"
                rel = t.split("/", 1)[1]
            else:
                continue  # not a recognised repo-relative path
            if any(c in rel for c in "*?"):
                if not list(base.glob(rel)):
                    missing.append({"doc": dpath, "token": tok, "reason": "glob matches nothing"})
            elif not (base / rel).exists():
                missing.append({"doc": dpath, "token": tok, "reason": "path does not exist"})
    return missing


# --- rules / context selection (§4) ----------------------------------------
def areas_for_paths(paths: list[str], areas: list[dict]) -> list[str]:
    pats = {a["id"]: [glob_to_regex(g) for g in a.get("code", [])] for a in areas}
    hit: set[str] = set()
    for f in paths:
        for aid, ps in pats.items():
            if any(p.match(f) for p in ps):
                hit.add(aid)
    return sorted(hit)


def parse_frontmatter(text: str) -> dict | None:
    """Parse a leading ``---`` YAML frontmatter block (small subset)."""
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    return _parse_yaml_block(m.group(1))


def _parse_scalar(s: str):
    s = s.strip()
    if s in ("null", "~", ""):
        return None
    if s.startswith("[") and s.endswith("]"):
        inner = s[1:-1].strip()
        if not inner:
            return []
        return [_parse_scalar(x) for x in _split_flow(inner)]
    if (s[0] == s[-1]) and s[0] in "\"'":
        return s[1:-1]
    if s in ("true", "false"):
        return s == "true"
    if re.fullmatch(r"-?\d+", s):
        return int(s)
    return s


def _split_flow(inner: str) -> list[str]:
    parts, depth, buf = [], 0, ""
    for ch in inner:
        if ch in "[{":
            depth += 1
        elif ch in "]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(buf); buf = ""
        else:
            buf += ch
    if buf.strip():
        parts.append(buf)
    return parts


def _parse_yaml_block(block: str) -> dict:
    """Parse a flat mapping whose values are scalars, flow lists, or block lists."""
    data: dict = {}
    key = None
    lines = block.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        if not raw.strip() or raw.strip().startswith("#"):
            i += 1; continue
        m = re.match(r"^(\S[^:]*):\s*(.*)$", raw)
        if m:
            key = m.group(1).strip()
            val = m.group(2).strip()
            if val == "":
                # maybe a block list follows
                block_items = []
                j = i + 1
                while j < len(lines) and re.match(r"^\s*-\s+", lines[j]):
                    block_items.append(_parse_scalar(re.sub(r"^\s*-\s+", "", lines[j])))
                    j += 1
                data[key] = block_items if block_items else None
                i = j; continue
            data[key] = _parse_scalar(val)
        i += 1
    return data


def load_rules(rules_dir: Path) -> list[dict]:
    """Each knowledge/rules/<ID>.md -> {path, frontmatter, body}."""
    out = []
    if not rules_dir.exists():
        return out
    for p in sorted(rules_dir.glob("*.md")):
        text = p.read_text()
        fm = parse_frontmatter(text) or {}
        body = re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.S)
        out.append({"path": p, "id": fm.get("id"), "frontmatter": fm, "body": body})
    return out


def rules_for_paths(paths: list[str], areas: list[dict], rules: list[dict]) -> list[str]:
    """Deterministic rule selection for a set of changed files (§4)."""
    sel_areas = set(areas_for_paths(paths, areas)) | {"all"}
    chosen: set[str] = set()
    for r in rules:
        fm = r["frontmatter"]
        rid = fm.get("id")
        if not rid:
            continue
        if fm.get("status") == "superseded":
            continue
        rule_areas = set(fm.get("areas") or [])
        applies = fm.get("applies_to") or []
        if rule_areas & sel_areas:
            chosen.add(rid); continue
        if any(glob_to_regex(g).match(f) for g in applies for f in paths):
            chosen.add(rid)
    return sorted(chosen)


def parse_context_manifest(text: str) -> dict | None:
    """Extract the ``context:`` block of a sub-spec (areas/rules/read/depends_on)."""
    m = re.search(r"^context:\s*\n((?:[ \t]+.*\n?)+)", text, re.M)
    if not m:
        return None
    block = "\n".join(re.sub(r"^  ", "", ln) for ln in m.group(1).splitlines())
    return _parse_yaml_block(block)


# --- build / budget --------------------------------------------------------
def strip_provenance(text: str) -> str:
    text = PROVENANCE_RE.sub("", text)
    # collapse blank lines a stripped comment may leave
    return re.sub(r"[ \t]+\n", "\n", text)


def tokens(text: str) -> int:
    return math.ceil(len(text) / 4)


def build_store(knowledge: Path) -> dict[str, str]:
    """Deterministically build the agent-loaded store. Returns {relpath: content}.

    * ``CORE.md`` from ``core.md`` (provenance stripped);
    * ``areas/<a>/SKILL.md`` = the pack + the full text of its active rules
      (frontmatter name/description prepended);
    * ``procedures/<p>/SKILL.md`` from ``procedures/<p>.md``.
    """
    built: dict[str, str] = {}
    core = knowledge / "core.md"
    if core.exists():
        built["CORE.md"] = _frontmatter("core", "Genesis core knowledge (always loaded).") + \
            strip_provenance(core.read_text()).strip() + "\n"
    rules = load_rules(knowledge / "rules")
    areas_root = knowledge / "areas"
    if areas_root.exists():
        for adir in sorted(p for p in areas_root.iterdir() if p.is_dir()):
            pack = adir / "pack.md"
            if not pack.exists():
                continue
            aid = adir.name
            parts = [_frontmatter(aid, f"Area pack for {aid} (loaded per task)."),
                     strip_provenance(pack.read_text()).strip()]
            arules = [r for r in rules
                      if aid in (r["frontmatter"].get("areas") or [])
                      and r["frontmatter"].get("status") != "superseded"]
            for r in sorted(arules, key=lambda r: r["id"] or ""):
                parts.append(f"\n## Rule {r['id']}\n" + strip_provenance(r["body"]).strip())
            built[f"areas/{aid}/SKILL.md"] = "\n\n".join(parts).strip() + "\n"
    procs = knowledge / "procedures"
    if procs.exists():
        for p in sorted(procs.glob("*.md")):
            name = p.stem
            built[f"procedures/{name}/SKILL.md"] = \
                _frontmatter(name, f"Procedure: {name}.") + strip_provenance(p.read_text()).strip() + "\n"
    return built


def _frontmatter(name: str, description: str) -> str:
    return f"---\nname: {name}\ndescription: {description}\n---\n\n"


def build_check(knowledge: Path, out_dir: Path | None = None) -> list[str]:
    """Return the list of stale/missing built files (empty => fresh)."""
    out_dir = out_dir or (knowledge / "_build")
    want = build_store(knowledge)
    stale = []
    for rel, content in want.items():
        f = out_dir / rel
        if not f.exists() or f.read_text() != content:
            stale.append(rel)
    if out_dir.exists():
        have = {str(p.relative_to(out_dir)) for p in out_dir.rglob("*.md")}
        for extra in sorted(have - set(want)):
            stale.append(f"{extra} (orphan)")
    return sorted(stale)


def write_build(knowledge: Path, out_dir: Path | None = None) -> list[str]:
    out_dir = out_dir or (knowledge / "_build")
    want = build_store(knowledge)
    written = []
    for rel, content in want.items():
        f = out_dir / rel
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(content)
        written.append(rel)
    return sorted(written)


def budget_report(built: dict[str, str]) -> list[dict]:
    """Per built doc: tokens vs its §7 limit; ``over=True`` when it breaches."""
    rep = []
    for rel, content in sorted(built.items()):
        if rel == "CORE.md":
            kind = "core"
        elif rel.startswith("areas/") and rel.endswith("/SKILL.md"):
            kind = "pack"
        elif rel.startswith("procedures/"):
            kind = "procedure"
        elif "/reference/" in rel:
            kind = "reference"
        else:
            kind = "pack"
        tok = tokens(content)
        limit = BUDGETS[kind]
        rep.append({"doc": rel, "kind": kind, "tokens": tok, "limit": limit, "over": tok > limit})
    return rep


# --- store validator -------------------------------------------------------
def validate_store(knowledge: Path, repo_files: set[str] | None = None) -> list[str]:
    errs: list[str] = []
    rule_schema = load_schema("rule.frontmatter.schema.json")
    rules = load_rules(knowledge / "rules")
    ids: set[str] = set()
    status: dict[str, str] = {}
    for r in rules:
        rid = r["id"]
        fm = r["frontmatter"]
        for e in schema_validate(rule_schema, fm):
            errs.append(f"{r['path'].name}: frontmatter: {e}")
        if rid in ids:
            errs.append(f"{r['path'].name}: duplicate rule id {rid}")
        ids.add(rid)
        status[rid] = fm.get("status")
        for a in fm.get("areas") or []:
            if a not in ALL_AREAS:
                errs.append(f"{r['path'].name}: unknown area {a}")
        # P3: a rule's applies_to glob must match at least one real file in the repos.
        if repo_files is not None:
            for g in fm.get("applies_to") or []:
                rx = glob_to_regex(g)
                if not any(rx.match(f) for f in repo_files):
                    errs.append(f"{r['path'].name}: applies_to glob {g!r} matches no file in the code repos")
    # markdown files (authored): provenance, state facts, links, archive links
    for md in sorted(knowledge.rglob("*.md")):
        if "_build" in md.parts:
            continue
        rel = md.relative_to(knowledge)
        parts = rel.parts
        text = md.read_text()
        in_state = parts[0] == "state"
        in_rules = parts[0] == "rules"
        # "current knowledge" prose docs that must carry provenance and must not
        # restate per-release state facts (rules trace via their id; history/state excluded).
        needs_prov = (md.name in ("core.md", "pack.md")
                      or "procedures" in parts or "reference" in parts)
        # links resolve + no archive links
        for m in MD_LINK_RE.finditer(text):
            target = m.group(1).split("#")[0].strip()
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            if "archive/" in target and not str(rel).endswith("history/INDEX.md"):
                errs.append(f"{rel}: link into archive/: {target}")
            resolved = (md.parent / target).resolve()
            if not resolved.exists():
                errs.append(f"{rel}: dangling link: {target}")
        # state facts only in state/ (code spans/fences and URLs stripped first)
        if needs_prov and not in_state:
            scan = _strip_urls(_strip_code_only(text))
            for pat, label in STATE_FACT_PATTERNS:
                mm = pat.search(scan)
                if mm:
                    errs.append(f"{rel}: {label} {mm.group(0)!r} outside state/current.yaml")
        # provenance on every authored prose paragraph
        if needs_prov:
            errs.extend(_provenance_errors(rel, text))
    # superseded rule referenced by an active pack
    for adir in sorted((knowledge / "areas").glob("*")) if (knowledge / "areas").exists() else []:
        pack = adir / "pack.md"
        if not pack.exists():
            continue
        ptext = pack.read_text()
        for rid in re.findall(r"\b((?:ADR|LSN|STD|WA)-\d{3})\b", ptext):
            if status.get(rid) == "superseded":
                errs.append(f"{adir.name}/pack.md: references superseded rule {rid}")
    # budgets
    for b in budget_report(build_store(knowledge)):
        if b["over"]:
            errs.append(f"budget: {b['doc']} {b['tokens']} tokens > {b['limit']}")
    return errs


def _strip_code_only(text: str) -> str:
    out, in_fence = [], False
    for ln in text.splitlines():
        if FENCE_RE.match(ln):
            in_fence = not in_fence; continue
        if not in_fence:
            out.append(INLINE_CODE_RE.sub(" ", ln))
    return "\n".join(out)


def _strip_urls(text: str) -> str:
    """Drop URL noise before the state-fact scan (review S1): keep a markdown
    link's TEXT but drop the ``(target)``; remove autolinks ``<scheme://…>`` and
    bare ``scheme://…`` URLs — a version inside a URL is not a per-release
    assertion, but the visible link text is still scanned."""
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)      # [text](url) -> text
    text = re.sub(r"<(?:https?|ftp)://[^>\s]+>", " ", text)   # <autolink>
    text = re.sub(r"\b(?:https?|ftp)://\S+", " ", text)       # bare URL
    return text


def _provenance_errors(rel, text: str) -> list[str]:
    errs = []
    body = re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.S)
    # split into paragraphs; a prose paragraph must carry a src/verbatim marker.
    in_fence = False
    para: list[str] = []
    def flush(p):
        joined = "\n".join(p).strip()
        if not joined:
            return
        if all(_is_heading(x) or not _nonblank(x) for x in p):
            return  # headings only
        if re.match(r"^\s*(?:[-*+]|\d+[.)])\s", joined) and len(p) == 1:
            pass  # single list line still needs provenance in packs/core
        if PROVENANCE_RE.search(joined) or VERBATIM_RE.search(joined):
            return
        errs.append(f"{rel}: paragraph without provenance near {p[0][:40]!r}")
    for ln in body.splitlines():
        if FENCE_RE.match(ln):
            in_fence = not in_fence
            para.append(ln); continue
        if in_fence:
            para.append(ln); continue
        if ln.strip() == "":
            flush(para); para = []
        else:
            para.append(ln)
    flush(para)
    return errs


# --- sampling --------------------------------------------------------------
def sample(seed: int, kind: str, n: int, *, units=None, inventory=None, docs=None) -> list:
    """Reproducible samples for reviewers (same seed => same output)."""
    import random
    rng = random.Random(seed)
    if kind == "ledger":
        pool = list(units or [])
        rng.shuffle(pool)
        return pool[:n]
    if kind == "source":
        inv = inventory or {}
        extract = [(p, d["lines"]) for p, d in sorted(inv.items()) if d["class"] == "extract" and d["lines"] > 0]
        out = []
        for _ in range(n):
            if not extract:
                break
            path, nlines = extract[rng.randrange(len(extract))]
            a = rng.randint(1, nlines)
            b = min(nlines, a + rng.randint(0, 20))
            out.append({"src": path, "lines": [a, b]})
        return out
    if kind == "doc":
        pool = list(docs or [])
        rng.shuffle(pool)
        return pool[:n]
    raise GkError(f"unknown sample kind: {kind}")


# --- id allocation ---------------------------------------------------------
def next_id(prefix: str, rules_dir: Path | None = None) -> str:
    if prefix not in ("LSN", "STD", "WA"):
        raise GkError("next-id prefix must be one of LSN, STD, WA (ADR ids come from decision-log)")
    rules_dir = rules_dir or (KNOWLEDGE / "rules")
    hi = 0
    if rules_dir.exists():
        for p in rules_dir.glob(f"{prefix}-*.md"):
            m = re.match(rf"{prefix}-(\d+)", p.stem)
            if m:
                hi = max(hi, int(m.group(1)))
    return f"{prefix}-{hi + 1:03d}"


# --- batch boundary safety (47-01 review P1) -------------------------------
def _is_list_item(ln: str) -> bool:
    return bool(re.match(r"\s*(?:[-*+]|\d+[.)])\s", ln))


def _is_table_row(ln: str) -> bool:
    return ln.strip().startswith("|")


def unsafe_boundaries(lines: list[str], ranges: list[tuple[int, int]]) -> list[int]:
    n = len(lines)
    fence_open = [False] * (n + 2)
    inside = False
    for i in range(1, n + 1):
        if FENCE_RE.match(lines[i - 1]):
            inside = not inside
        fence_open[i] = inside
    def blank(i):
        return 1 <= i <= n and lines[i - 1].strip() == ""
    bad = []
    for s in sorted(a for (a, _) in ranges):
        if s == 1 or not (1 <= s - 1 < n):
            continue
        L = s - 1
        if fence_open[L]:
            bad.append(s); continue
        lL, lN = lines[L - 1], lines[s - 1]
        if blank(L) or blank(s) or _is_heading(lN):
            continue
        if _is_list_item(lL) and _is_list_item(lN) and not _is_table_row(lL) and not _is_table_row(lN):
            continue
        bad.append(s)
    return bad


def check_batches_boundaries(batches: list[dict], blob_lines=base_lines) -> list[str]:
    errs = []
    covered: dict[str, list] = {}
    for b in batches:
        for (src, a, bb, _ch) in b["entries"]:
            covered.setdefault(src, []).append((a, bb))
    for src, ranges in covered.items():
        if len(ranges) < 2:
            continue
        try:
            lines = blob_lines(src)
        except GkError as e:
            errs.append(str(e)); continue
        for s in unsafe_boundaries(lines, ranges):
            errs.append(f"{src}: unsafe split boundary before line {s}")
    return errs


def check_batches_all(inventory: dict[str, dict], batches: list[dict], char_limit: int,
                      blob_lines=base_lines) -> tuple[list[str], dict]:
    """The single batch-plan check shared by ``gk batches check`` and
    ``migration/scripts/check_batches.py``: exact-once tiling of every extract
    file (no gap/overlap), the per-batch char cap, no archive-only file in a
    batch, per-file recorded chars == inventory, unique/contiguous ids, **and**
    boundary safety (via :func:`unsafe_boundaries`). Returns ``(errs, stats)``.
    """
    extract = {p: v for p, v in inventory.items() if v["class"] == "extract"}
    archive = {p for p, v in inventory.items() if v["class"] != "extract"}
    errs: list[str] = []
    covered: dict[str, list] = {}
    recorded: dict[str, int] = {}
    ids: list[str] = []
    for b in batches:
        ids.append(b["id"])
        tot = 0
        for (src, a, bb, ch) in b["entries"]:
            tot += ch
            if src in archive:
                errs.append(f"{b['id']}: archive-only file in batch: {src}")
            covered.setdefault(src, []).append((a, bb))
            recorded[src] = recorded.get(src, 0) + ch
        if b["chars"] is not None and tot != b["chars"]:
            errs.append(f"{b['id']}: declared chars {b['chars']} != sum of entries {tot}")
        if tot > char_limit:
            errs.append(f"{b['id']}: {tot} chars exceeds limit {char_limit}")
    for path, info in extract.items():
        ranges = sorted(covered.get(path, []))
        if not ranges:
            errs.append(f"MISSING from batches: {path}"); continue
        expect = 1
        for (a, b) in ranges:
            if a != expect:
                errs.append(f"{path}: gap/overlap — range starts at {a}, expected {expect}"); break
            expect = b + 1
        else:
            if expect - 1 != info["lines"]:
                errs.append(f"{path}: covered to line {expect-1}, file has {info['lines']} lines")
        if recorded.get(path) != info["chars"]:
            errs.append(f"{path}: batch chars {recorded.get(path)} != inventory chars {info['chars']}")
    for path in covered:
        if path not in extract:
            errs.append(f"not an extract source (or unknown): {path}")
    if len(ids) != len(set(ids)):
        errs.append("duplicate batch ids")
    p_ids = [i for i in ids if re.fullmatch(r"P\d+", i)]
    b_ids = [i for i in ids if re.fullmatch(r"B\d+", i)]
    if not p_ids:
        errs.append("no pilot (P) batches")
    exp = [f"B{i:02d}" for i in range(1, len(b_ids) + 1)]
    if b_ids != exp:
        errs.append(f"B-series not contiguous: {b_ids[:3]}..{b_ids[-3:]} vs {exp[:3]}..{exp[-3:]}")
    # boundary safety on every multi-entry source
    bchecked = 0
    for src, ranges in covered.items():
        if src not in extract or len(ranges) < 2:
            continue
        try:
            lines = blob_lines(src)
        except GkError as e:
            errs.append(str(e)); continue
        bchecked += 1
        for s in unsafe_boundaries(lines, ranges):
            errs.append(f"{src}: unsafe split boundary before line {s} "
                        f"(cuts inside a paragraph/table/list-item/code block)")
    stats = {
        "batches": len(batches), "p": len(p_ids), "b": len(b_ids),
        "extract": len(extract), "covered": len(covered),
        "entries": sum(len(x["entries"]) for x in batches),
        "total_chars": sum(sum(e[3] for e in x["entries"]) for x in batches),
        "inv_chars": sum(v["chars"] for v in extract.values()),
        "max_chars": max((sum(e[3] for e in x["entries"]) for x in batches), default=0),
        "char_limit": char_limit, "boundary_checked": bchecked,
    }
    return errs, stats


def repo_files(code_root: Path, repos: list[str]) -> set[str]:
    """Repo-prefixed tracked files across the code repos at HEAD (for P3/exact)."""
    out: set[str] = set()
    for r in repos:
        d = code_root / r
        if not (d / ".git").exists():
            continue
        for f in _git("ls-files", repo=d).splitlines():
            if f:
                out.add(f"{r}/{f}")
    return out
