#!/usr/bin/env bash
# L-112 / 53-12 precondition: the CI job scripts of .gitlab-ci.yml (genesis, genesis-core, kiro-agent-sdk,
# genesis-appian-parser) in python:3.13, on a clean clone of genesis 61ec063 (with .git, as CI has).
# The tree is streamed in as a tar on stdin (colima shares only $HOME, not /tmp), so pytest runs on the
# container's own disk.
set -u
COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs -C /tmp/genesis-53-11/img-src -cf - . | docker run --rm -i python:3.13 bash -c '
set -u
mkdir /src && tar -xf - -C /src && cd /src
git config --global --add safe.directory /src
echo "== AppleDouble files: $(find . -name "._*" | wc -l)"; echo "== HEAD $(git log --oneline -1 | cut -c1-7)  status: $(git status --short | wc -l) changed"
echo "== python $(python --version)  node: $(command -v node || echo none)  kiro-cli: $(command -v kiro-cli || echo none)"
scripts/install-packages.sh --editable --dev --python python > /tmp/install.log 2>&1; echo "== install exit $?"; tail -3 /tmp/install.log
echo "== genesis ruff"; ruff check genesis; echo "exit $?"
echo "== genesis pytest"; pytest -q 2>&1 | tail -30; echo "exit ${PIPESTATUS[0]}"
cd packages/genesis-core
echo "== genesis-core ruff"; ruff check genesis_core; echo "exit $?"
echo "== genesis-core pytest"; pytest -q -p no:warnings 2>&1 | tail -8; echo "exit ${PIPESTATUS[0]}"
cd ../kiro-agent-sdk
echo "== sdk ruff"; ruff check src tests; echo "exit $?"
echo "== sdk pytest"; pytest -q 2>&1 | tail -8; echo "exit ${PIPESTATUS[0]}"
cd ../genesis-appian-parser
echo "== parser ruff"; ruff check .; echo "exit $?"
echo "== parser pytest"; pytest -q 2>&1 | tail -8; echo "exit ${PIPESTATUS[0]}"
'
