#!/usr/bin/env bash
# stop-lint.sh [--specs-only] — Stop hook (Phase 47, 47-06 §8).
#
# Runs `genesis-ctx lint`; if it is not green, asks the agent to continue and fix it — but at most
# TWICE per session (a counter keyed by session_id in $TMPDIR), then stands down and leaves the
# summary for the operator. Kiro CLI 3 Stop semantics (probed/doc 2026-10-20): printing
# {"decision":"block","reason":...} on stdout with exit 0 makes the agent take another turn; exit 0
# with no decision lets it finish. Reads the hook event JSON (for session_id) on stdin.
set -uo pipefail

specs_only=0
[[ "${1:-}" == "--specs-only" ]] && specs_only=1

payload="$(cat 2>/dev/null || true)"

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ctx="$here/../bin/genesis-ctx"
[[ -x "$ctx" ]] || ctx="genesis-ctx"

if [[ $specs_only -eq 1 ]]; then
  summary="$("$ctx" lint --quiet --specs-only 2>&1)"; rc=$?
else
  summary="$("$ctx" lint --quiet 2>&1)"; rc=$?
fi
[[ $rc -eq 0 ]] && exit 0

py="${GENESIS_CTX_PYTHON:-}"
if [[ -z "$py" ]]; then
  for c in python3 python3.14 python3.13 python3.12 python3.11; do
    command -v "$c" >/dev/null 2>&1 && { py="$c"; break; }
  done
fi

sid=""
if [[ -n "$py" ]]; then
  sid="$(GENESIS_HOOK_PAYLOAD="$payload" "$py" -c 'import json,os,sys;sys.stdout.write(str((json.loads(os.environ.get("GENESIS_HOOK_PAYLOAD","") or "{}") or {}).get("session_id","")))' 2>/dev/null || true)"
fi
[[ -z "$sid" ]] && sid="nosid"
cnt_file="${TMPDIR:-/tmp}/genesis-stop-${sid}"
n=0; [[ -f "$cnt_file" ]] && n="$(cat "$cnt_file" 2>/dev/null || echo 0)"
[[ "$n" =~ ^[0-9]+$ ]] || n=0

if [[ "$n" -lt 2 ]]; then
  echo $((n + 1)) > "$cnt_file"
  reason="genesis-ctx lint is not green yet: ${summary}. Fix the findings (do NOT edit source docs by hand — use genesis-ctx add/index), then finish."
  if [[ -n "$py" ]]; then
    GENESIS_REASON="$reason" "$py" -c 'import json,os;print(json.dumps({"decision":"block","reason":os.environ["GENESIS_REASON"]}))'
  else
    printf '{"decision":"block","reason":"genesis-ctx lint is not green; run genesis-ctx lint and fix the findings."}\n'
  fi
  exit 0
fi

{
  echo "genesis-ctx lint still failing after 2 continue attempts — leaving it for you:"
  echo "$summary"
} >&2
exit 0
