"""47-09 §2 golden-question tooling (genesis-review, read-only on code).

  python golden_grade.py prompt <batch 1..4>         -> the prompt for one fresh genesis-dev session (10 questions)
  python golden_grade.py grade <answers.txt>...      -> per-question PASS/FAIL + overall / critical rates

Grading (deterministic, no model): an answer passes when it cites EVERY expected id and contains the key phrase.
Answers are split on lines that start with `Qnn` (the prompt asks for that format). Ids match with or without
leading zeros (ADR-31 == ADR-031). The phrase match is case-insensitive and treats "-", "_" and whitespace alike.
Pass bar (47-09 §2): >= 95 % overall and 100 % of `critical`.
"""
from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

HERE = Path(__file__).resolve().parent
GOLDEN = HERE / "golden.toml"
PER_BATCH = 10


def load() -> list[dict]:
    return tomllib.loads(GOLDEN.read_text(encoding="utf-8"))["q"]


def prompt(batch: int) -> str:
    qs = load()[(batch - 1) * PER_BATCH: batch * PER_BATCH]
    lines = [
        "Answer each question below; cite the ADR/lesson ids; use genesis-ctx as you normally would.",
        "Do not change any file. Start each answer on its own line with its id exactly as given (e.g. `Q01:`), "
        "and keep each answer to a few sentences.",
        "",
    ]
    lines += [f"{q['id']}: {q['ask']}" for q in qs]
    return "\n".join(lines)


def _norm(s: str) -> str:
    return re.sub(r"[\s_\-]+", " ", s.lower())


def _ids(text: str) -> set[str]:
    out = set()
    for kind, num in re.findall(r"\b(ADR|L)-0*(\d{1,3})\b", text):
        out.add(f"{kind}-{int(num):03d}")
    return out


def split_answers(text: str) -> dict[str, str]:
    parts = re.split(r"(?m)^[\s>*#|`-]*\**(Q\d{2})\**\s*[:.)\-—|]", text)
    out: dict[str, str] = {}
    for i in range(1, len(parts) - 1, 2):
        out[parts[i]] = out.get(parts[i], "") + parts[i + 1]   # last mention wins by appending
    return out


def grade(paths: list[str]) -> int:
    answers: dict[str, str] = {}
    for p in paths:
        answers.update(split_answers(Path(p).read_text(encoding="utf-8", errors="replace")))
    rows, ok, crit, crit_ok = [], 0, 0, 0
    for q in load():
        a = answers.get(q["id"])
        if a is None:
            continue
        got = _ids(a)
        miss_ids = [i for i in q["expect"] if i not in got]
        has_phrase = _norm(q["phrase"]) in _norm(a)
        passed = not miss_ids and has_phrase
        ok += passed
        if q["critical"]:
            crit += 1
            crit_ok += passed
        why = []
        if miss_ids:
            why.append("missing " + ", ".join(miss_ids))
        if not has_phrase:
            why.append(f"no phrase `{q['phrase']}`")
        rows.append(f"| {q['id']} | {q['area']} | {'yes' if q['critical'] else ''} | "
                    f"{'PASS' if passed else 'FAIL'} | {'; '.join(why)} |")
    unanswered = [q["id"] for q in load() if q["id"] not in answers]
    print("| q | area | critical | result | why |\n|---|---|---|---|---|")
    print("\n".join(rows))
    n = len(rows)
    print(f"\nanswered {n}/{len(load())}" + (f" (unanswered: {', '.join(unanswered)})" if unanswered else ""))
    if n:
        print(f"overall {ok}/{n} = {ok / n:.1%} · critical {crit_ok}/{crit} = {(crit_ok / crit if crit else 1):.0%}")
    passed = n == len(load()) and ok / n >= 0.95 and crit_ok == crit
    print("GATE:", "PASS" if passed else "FAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "prompt":
        print(prompt(int(sys.argv[2])))
    elif len(sys.argv) >= 3 and sys.argv[1] == "grade":
        sys.exit(grade(sys.argv[2:]))
    else:
        print(__doc__)
        sys.exit(2)
