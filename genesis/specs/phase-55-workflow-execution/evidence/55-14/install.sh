#!/usr/bin/env bash
# 55-14: install the staged genesis tree in the python:3.13 CI image (as .gitlab-ci.yml's before_script).
set -u
cd /w/genesis
scripts/install-packages.sh --editable --dev --no-model --python python > /w/out/install.txt 2>&1
echo "install exit=$?"
python -c "import genesis, genesis_core, kiro_agent_sdk, genesis_appian_parser; print('ok')"
pip list 2>/dev/null | grep -i -E "pytest|repeat|xdist|randomly"
