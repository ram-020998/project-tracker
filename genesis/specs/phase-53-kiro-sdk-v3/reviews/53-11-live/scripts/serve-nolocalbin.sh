#!/usr/bin/env bash
# A3b: the 53-11 serve with a PATH that has no ~/.local/bin (as a GUI- or launchd-started app sees it), so kiro-cli is
# found only through the SDK's ~/.local/bin fallback.
export GENESIS_STATE_DIR=/tmp/genesis-53-11/state
export GENESIS_ARTIFACTS_DIR=/tmp/genesis-53-11/artifacts
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
cd /tmp/genesis-53-11 || exit 1
exec /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv/bin/genesis serve --host 127.0.0.1 --port 8770 \
  >/tmp/genesis-53-11/serve-5-nolocalbin.log 2>&1
