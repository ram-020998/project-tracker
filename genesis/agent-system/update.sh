#!/usr/bin/env bash
# update.sh [--pull] [--dry-run] [--force] — re-render and apply only what changed (47-07 §3): prints
# added / changed / removed / unchanged, backs up changed and removed files, rewrites the manifest.
set -euo pipefail
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$here/tools/installer/run.sh" update "$@"
