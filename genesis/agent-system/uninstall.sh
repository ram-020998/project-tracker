#!/usr/bin/env bash
# uninstall.sh [--dry-run] — remove exactly the files in the manifest (backed up first) and the manifest (47-07 §3).
# Leaves ~/.kiro/genesis/backups/.
set -euo pipefail
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$here/tools/installer/run.sh" uninstall "$@"
