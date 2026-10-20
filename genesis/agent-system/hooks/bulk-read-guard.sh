#!/usr/bin/env bash
# bulk-read-guard.sh — PreToolUse hook on the `read` tool (Phase 47, 47-06 §8).
#
# Blocks a WHOLE-FILE read of the big source documents (reference/decision-log.md, bible/03|04|06,
# archive/**, tracker.md) so an agent uses `genesis-ctx adr|lesson|area|search` or a bounded range
# instead. Ranged reads (a limit, or a non-zero offset) and every other path are allowed.
#
# Kiro CLI 3 feeds the hook event JSON on stdin; exit 2 blocks the tool and stderr reaches the agent
# (probed 2026-10-20: tool_name="read_file", tool_input={"path","offset","limit"}). Fails OPEN (exit 0)
# if anything is unexpected — the L0 retrieval protocol and the review gate are the backstop.
set -uo pipefail

py="${GENESIS_CTX_PYTHON:-}"
if [[ -z "$py" ]]; then
  for c in python3 python3.14 python3.13 python3.12 python3.11; do
    command -v "$c" >/dev/null 2>&1 && { py="$c"; break; }
  done
fi
[[ -z "$py" ]] && exit 0

payload="$(cat 2>/dev/null || true)"
GENESIS_HOOK_PAYLOAD="$payload" exec "$py" - <<'PY'
import json, os, re, sys
try:
    e = json.loads(os.environ.get("GENESIS_HOOK_PAYLOAD", "") or "{}")
except Exception:
    sys.exit(0)
ti = e.get("tool_input") or {}
path = str(ti.get("path") or "")
offset, limit = ti.get("offset"), ti.get("limit")
ranged = (isinstance(limit, int) and limit > 0) or (isinstance(offset, int) and offset > 0)
PROTECTED = (
    r"reference/decision-log\.md$",
    r"bible/0[346][^/]*\.md$",
    r"(^|/)archive/",
    r"(^|/)tracker\.md$",
)
if path and not ranged and any(re.search(p, path) for p in PROTECTED):
    name = path.rsplit("/", 1)[-1]
    sys.stderr.write(
        f"genesis bulk-read-guard: refusing a whole-file read of `{name}`. "
        "Use `genesis-ctx adr|lesson|area <id>` or `genesis-ctx search <term> --archive`, "
        "or read a bounded range (pass a `limit`)."
    )
    sys.exit(2)
sys.exit(0)
PY
