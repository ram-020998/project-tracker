#!/usr/bin/env bash
# The 53-11 test instance: its own state + artifacts dirs, port 8770 (reports :8870). Not the fleet.
# Usage: serve.sh <log-suffix> [extra PATH prefix]
set -u
export GENESIS_STATE_DIR=/tmp/genesis-53-11/state
export GENESIS_ARTIFACTS_DIR=/tmp/genesis-53-11/artifacts
if [ -n "${2:-}" ]; then
  export PATH="$2:$PATH"
fi
cd /tmp/genesis-53-11 || exit 1
exec /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv/bin/genesis serve --host 127.0.0.1 --port 8770 \
  >"/tmp/genesis-53-11/serve-$1.log" 2>&1
