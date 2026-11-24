#!/usr/bin/env bash
# 55-11 §3: the release candidate (genesis 76b27a57, non-editable scratch venv) on the COPY of the Genesis home.
# Never the fleet's state, port or API base: the Resolve MCP and the copilot talk to GENESIS_API_BASE.
export GENESIS_STATE_DIR=/tmp/gr-55-11/state
export GENESIS_ARTIFACTS_DIR=/tmp/gr-55-11/runs
export GENESIS_API_BASE=http://127.0.0.1:8790
unset GENESIS_COLLAB_ENABLED GENESIS_COLLAB_PROVIDER GENESIS_COLLAB_HUB_APP_UUID GENESIS_COLLAB_HUB_URL
exec /tmp/gr-55-11/venv/bin/genesis serve --host 127.0.0.1 --port 8790
