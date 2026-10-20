#!/usr/bin/env bash
# install.sh [--dry-run] [--force] — install the Genesis agents, skills, hooks and the genesis-ctx shim (47-07 §3).
# Refuses to overwrite files it did not install unless --force (which backs them up first).
set -euo pipefail
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$here/tools/installer/run.sh" install "$@"
