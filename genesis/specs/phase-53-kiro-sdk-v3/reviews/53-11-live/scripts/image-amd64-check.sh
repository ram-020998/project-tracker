#!/usr/bin/env bash
# The 4 tests that failed in the aarch64 python:3.13 run, on 61ec063 in python:3.13 linux/amd64 (the CI runner's arch,
# emulated by colima), to split arch failures from real ones.
set -u
COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs -C /tmp/genesis-53-11/img-src -cf - . | docker run --rm -i --platform linux/amd64 python:3.13 bash -c '
set -u
mkdir /src && tar -xf - -C /src && cd /src
git config --global --add safe.directory /src
echo "== HEAD $(git log --oneline -1 | cut -c1-7)  arch $(uname -m)  TZ-date $(date -u)"
scripts/install-packages.sh --editable --dev --python python > /tmp/install.log 2>&1; echo "== install exit $?"
pytest -q -p no:warnings tests/test_sail_cli.py::test_extract_sail_binary_for_host tests/test_sail_cli.py::test_install_appian_dev_bundle_installs_both "tests/test_testexec_execution.py::test_regression_job_handler_starts_due_apps_and_skips_busy_ones" 2>&1 | tail -6; echo "exit ${PIPESTATUS[0]}"
cd packages/genesis-appian-parser && pytest -q tests/test_parse.py::test_parse_returns_populated_result 2>&1 | tail -3; echo "exit ${PIPESTATUS[0]}"
'
