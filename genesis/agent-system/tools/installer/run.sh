#!/usr/bin/env bash
# run.sh <install|update|uninstall> [options] — shared launcher for agent-system/{install,update,uninstall}.sh
# (Phase 47, 47-07). Picks a Python >= 3.11 (macOS /usr/bin/python3 is older) and runs the stdlib installer.
set -euo pipefail
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
py="${GENESIS_CTX_PYTHON:-}"
if [[ -z "$py" ]]; then
  for c in python3.14 python3.13 python3.12 python3.11 python3; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
      py="$c"
      break
    fi
  done
fi
if [[ -z "$py" ]]; then
  echo "genesis installer: needs Python >= 3.11 (or set GENESIS_CTX_PYTHON)" >&2
  exit 1
fi
exec "$py" "$here" "$@"
